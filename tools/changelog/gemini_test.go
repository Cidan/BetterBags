package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// interaction is the body of a completed interaction whose model output is text.
func interaction(status, text string) string {
	body := map[string]any{
		"id":     "int_1",
		"status": status,
		"steps": []any{
			map[string]any{"type": "thought", "summary": []any{map[string]any{"type": "text", "text": "thinking"}}},
			map[string]any{"type": "model_output", "content": []any{map[string]any{"type": "text", "text": text}}},
		},
	}
	out, _ := json.Marshal(body)
	return string(out)
}

const summaryJSON = `{"headline":"Tabs for every theme.","entries":[{"category":"New","title":"Themed tabs","details":"Tabs match the theme.","clients":[]}]}`

func newGemini(url string) (*Gemini, *[]time.Duration) {
	var slept []time.Duration
	return &Gemini{
		BaseURL:  url,
		Key:      "test-key",
		Model:    DefaultGeminiModel,
		HTTP:     &http.Client{Timeout: 5 * time.Second},
		Attempts: 3,
		Sleep:    func(d time.Duration) { slept = append(slept, d) },
	}, &slept
}

func TestSummarizeSendsAnInteraction(t *testing.T) {
	var got map[string]any
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.Method != http.MethodPost || r.URL.Path != "/v1beta/interactions" {
			t.Errorf("request %s %s", r.Method, r.URL.Path)
		}
		if r.Header.Get("x-goog-api-key") != "test-key" || r.URL.Query().Get("key") != "" {
			t.Errorf("the key was not sent in the header only")
		}
		if r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("content type %q", r.Header.Get("Content-Type"))
		}
		body, _ := io.ReadAll(r.Body)
		if calls == 1 {
			if err := json.Unmarshal(body, &got); err != nil {
				t.Errorf("body: %v", err)
			}
		}
		io.WriteString(w, interaction("completed", summaryJSON))
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)

	s, err := g.Summarize(context.Background(), "the commits")
	if err != nil {
		t.Fatalf("Summarize: %v", err)
	}
	if s.Headline != "Tabs for every theme." || len(s.Entries) != 1 || s.Entries[0].Title != "Themed tabs" {
		t.Errorf("summary = %+v", s)
	}
	if got["model"] != "gemini-4-hydrogen" || got["input"] != "the commits" || got["store"] != false {
		t.Errorf("model, input, store = %v, %v, %v", got["model"], got["input"], got["store"])
	}
	instruction, _ := got["system_instruction"].(string)
	for _, rule := range []string{
		"BetterBags", "new in this build", "never as separate Improved or Fixed entries", "Never say the same thing twice",
		"Every change a player can notice", "say where its job is now", "Never put unrelated changes in one entry",
		"Players never had those problems", "Leave out changes outside the addon",
		"applies to every version unless the commits say otherwise", "leave the change out rather than guess",
	} {
		if !strings.Contains(instruction, rule) {
			t.Errorf("system instruction lacks %q", rule)
		}
	}
	format, _ := got["response_format"].(map[string]any)
	if format["type"] != "text" || format["mime_type"] != "application/json" {
		t.Errorf("response format = %v", format)
	}
	schema, _ := format["schema"].(map[string]any)
	required, _ := schema["required"].([]any)
	if len(required) != 2 || required[0] != "headline" || required[1] != "entries" {
		t.Errorf("schema = %v", schema)
	}
	// Hydrogen thinks at high by default and counts its thinking against max_output_tokens.
	config, _ := got["generation_config"].(map[string]any)
	if config["thinking_level"] != "high" || config["max_output_tokens"] != float64(65536) {
		t.Errorf("generation config = %v", config)
	}
}

func TestSummarizeRetriesBusyAndFailingServers(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		switch calls {
		case 1:
			w.WriteHeader(http.StatusTooManyRequests)
		case 2:
			w.WriteHeader(http.StatusServiceUnavailable)
		default:
			io.WriteString(w, interaction("completed", summaryJSON))
		}
	}))
	defer server.Close()
	g, slept := newGemini(server.URL)
	if _, err := g.Summarize(context.Background(), "x"); err != nil {
		t.Fatalf("Summarize: %v", err)
	}
	// Two failures, the draft, then the review.
	if calls != 4 || len(*slept) != 2 || (*slept)[0] >= (*slept)[1] {
		t.Errorf("calls %d, slept %v", calls, *slept)
	}
}

func TestSummarizeGivesUpAfterItsAttempts(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)
	if _, err := g.Summarize(context.Background(), "x"); err == nil {
		t.Errorf("no error")
	}
	if calls != 3 {
		t.Errorf("calls = %d", calls)
	}
}

func TestSummarizeDoesNotRetryABadRequest(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.WriteHeader(http.StatusBadRequest)
		io.WriteString(w, `{"error":{"message":"bad schema"}}`)
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)
	_, err := g.Summarize(context.Background(), "x")
	if err == nil || !strings.Contains(err.Error(), "bad schema") || calls != 1 {
		t.Errorf("err %v, calls %d", err, calls)
	}
}

func TestSummarizeRejectsUnusableAnswers(t *testing.T) {
	answers := map[string]string{
		"incomplete":   interaction("incomplete", summaryJSON),
		"not JSON":     interaction("completed", "Here are the notes."),
		"invalid":      interaction("completed", `{"headline":"h","entries":[{"category":"Bogus","title":"t","details":"d","clients":[]}]}`),
		"no output":    `{"id":"int_1","status":"completed","steps":[{"type":"thought"}]}`,
		"broken reply": `{"id":`,
	}
	for name, answer := range answers {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			io.WriteString(w, answer)
		}))
		g, _ := newGemini(server.URL)
		if _, err := g.Summarize(context.Background(), "x"); err == nil {
			t.Errorf("%s: no error", name)
		}
		server.Close()
	}
}

// The review answers with its audit of every listed change before the notes; only the notes are kept.
const reviewedJSON = `{"coverage":[{"change":1,"notice":["Tabs match the theme"],"entries":["Themed tabs"]},{"change":2,"notice":[],"entries":[]},{"change":3,"notice":["Tabs fit under borders"],"entries":["Themed tabs"]}],"headline":"Reviewed.","entries":[{"category":"New","title":"Themed tabs","details":"Tabs match the theme, and fit under every border.","clients":[]}]}`

// The draft is reviewed by a second interaction: the commits, every change in them to account for
// and the draft go in, and the notes that come back are the build's.
func TestSummarizeReviewsItsDraft(t *testing.T) {
	var inputs []string
	var schemas []map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		raw, _ := io.ReadAll(r.Body)
		json.Unmarshal(raw, &body)
		input, _ := body["input"].(string)
		inputs = append(inputs, input)
		schema, ok := body["response_format"].(map[string]any)["schema"].(map[string]any)
		if !ok {
			t.Errorf("request %d has no schema", len(inputs))
		}
		schemas = append(schemas, schema)
		if len(inputs) == 1 {
			io.WriteString(w, interaction("completed", summaryJSON))
		} else {
			io.WriteString(w, interaction("completed", reviewedJSON))
		}
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)

	s, err := g.Summarize(context.Background(), "=== Commit: Themed tabs\n* Tabs drawn from the theme\n=== Commit: Fix the tabs under borders")
	if err != nil {
		t.Fatalf("Summarize: %v", err)
	}
	if len(inputs) != 2 {
		t.Fatalf("%d interactions", len(inputs))
	}
	if s.Headline != "Reviewed." || len(s.Entries) != 1 || s.Entries[0].Details != "Tabs match the theme, and fit under every border." {
		t.Errorf("summary = %+v", s)
	}
	review := inputs[1]
	for _, want := range []string{"Fix the tabs under borders", `"title": "Themed tabs"`, "Tabs match the theme.",
		"=== The changes to account for\n1. Themed tabs\n2. Tabs drawn from the theme\n3. Fix the tabs under borders\n"} {
		if !strings.Contains(review, want) {
			t.Errorf("the review lacks %q:\n%s", want, review)
		}
	}

	// The draft is asked for the notes alone; the review for its audit first, then the notes.
	if _, ok := schemas[0]["properties"].(map[string]any)["coverage"]; ok {
		t.Errorf("the draft's schema has a coverage: %v", schemas[0])
	}
	required, _ := schemas[1]["required"].([]any)
	if len(required) != 3 || required[0] != "coverage" || required[1] != "headline" || required[2] != "entries" {
		t.Errorf("the review's schema requires %v", required)
	}
	coverage, _ := schemas[1]["properties"].(map[string]any)["coverage"].(map[string]any)
	item, _ := coverage["items"].(map[string]any)
	itemRequired, _ := item["required"].([]any)
	if coverage["type"] != "array" || len(itemRequired) != 3 || itemRequired[0] != "change" || itemRequired[1] != "notice" || itemRequired[2] != "entries" {
		t.Errorf("the review's coverage is %v", coverage)
	}
	if _, ok := schemas[1]["properties"].(map[string]any)["entries"]; !ok {
		t.Errorf("the review's schema has no entries: %v", schemas[1])
	}
}

// A review that fails leaves the draft: it is valid notes already.
func TestSummarizeKeepsTheDraftWhenTheReviewFails(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			io.WriteString(w, interaction("completed", summaryJSON))
			return
		}
		w.WriteHeader(http.StatusBadRequest)
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)
	s, err := g.Summarize(context.Background(), "x")
	if err != nil || s.Headline != "Tabs for every theme." {
		t.Errorf("summary %+v, %v", s, err)
	}
}

// An entry keeps its clients only when its quote is the commits' own words and names each client:
// the in-game window hides an entry from every other client, so a guessed client hides a change
// from players who have it.
func TestSummarizeKeepsClientsOnlyWhenTheCommitsNameThem(t *testing.T) {
	const commits = "=== Commit: WoW: Forever launch fixes\nBoth changes apply on Forever only.\n" +
		"=== Commit: Guild bank logs\nEnable Guild Bank Window, the guild bank's on a client with one.\n" +
		"It operates on several clients the same way. Tabs stay at the bottom on retail, Forever and Classic.\n" +
		"=== Commit: Keyring\nThe keyring is read only on Vanilla and MoP.\n"
	entry := func(title string, clients []string, quote string) map[string]any {
		return map[string]any{"category": "Fixed", "title": title, "details": "d", "clients": clients, "clients_quote": quote}
	}
	draft, _ := json.Marshal(map[string]any{"headline": "Draft.", "entries": []any{
		map[string]any{"category": "New", "title": "Draft only", "details": "Only on Classic Era clients.", "clients": []string{}, "clients_quote": ""},
	}})
	reviewed, _ := json.Marshal(map[string]any{"coverage": []any{}, "headline": "Reviewed.", "entries": []any{
		entry("Forever login", []string{"Forever"}, "Both changes apply on Forever only."),
		entry("Folded quote", []string{"Forever"}, "  both changes apply\n on FOREVER only "),
		entry("Quoted quote", []string{"Forever"}, "“Both changes apply on Forever only.”"),
		entry("Typographic apostrophe", []string{"Retail", "Classic"}, "the guild bank’s on a client with one"),
		entry("Classic's other names", []string{"Classic"}, "The keyring is read only on Vanilla and MoP."),
		entry("Names no client", []string{"Retail", "Classic"}, "the guild bank's on a client with one"),
		entry("Names another client too", []string{"Retail", "Classic"}, "at the bottom on retail, Forever and Classic"),
		entry("Not in the commits", []string{"Classic"}, "the keyring exists only on Classic Era"),
		entry("No quote", []string{"Forever"}, ""),
		entry("Part of a word", []string{"Classic"}, "It operates on several clients"),
		entry("Quotes the draft", []string{"Classic"}, "Only on Classic Era clients."),
		entry("Names one of two", []string{"Retail", "Forever"}, "Both changes apply on Forever only."),
	}})
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			io.WriteString(w, interaction("completed", string(draft)))
			return
		}
		io.WriteString(w, interaction("completed", string(reviewed)))
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)
	s, err := g.Summarize(context.Background(), commits)
	if err != nil {
		t.Fatalf("Summarize: %v", err)
	}
	want := map[string]string{"Forever login": "Forever", "Folded quote": "Forever", "Quoted quote": "Forever",
		"Typographic apostrophe": "", "Classic's other names": "Classic", "Names no client": "", "Names another client too": "",
		"Not in the commits": "", "No quote": "", "Part of a word": "", "Quotes the draft": "", "Names one of two": ""}
	if len(s.Entries) != len(want) {
		t.Fatalf("entries %+v", s.Entries)
	}
	for _, e := range s.Entries {
		if got := strings.Join(e.Clients, ","); got != want[e.Title] {
			t.Errorf("%s: clients %q, want %q", e.Title, got, want[e.Title])
		}
	}
}

// A typographic apostrophe in a quote matches the commits' plain one: the quote is found, and only
// what it names decides the clients.
func TestAQuotesApostrophesMatchTheCommits(t *testing.T) {
	notes := geminiNotes{Headline: "h"}
	notes.Entries = append(notes.Entries, struct {
		Entry
		ClientsQuote string `json:"clients_quote"`
	}{Entry{Category: "Fixed", Title: "t", Clients: []string{"Forever"}}, "the keyring’s slots on Forever"})
	if s := notes.summary("The keyring's slots on Forever are open."); strings.Join(s.Entries[0].Clients, ",") != "Forever" {
		t.Errorf("clients %v", s.Entries[0].Clients)
	}
}

// The draft is the notes when the review fails, so its clients are checked the same way.
func TestTheDraftsClientsAreCheckedToo(t *testing.T) {
	const commits = "=== Commit: Login fix\nBoth changes apply on Forever only.\n"
	draft, _ := json.Marshal(map[string]any{"headline": "Draft.", "entries": []any{
		map[string]any{"category": "Fixed", "title": "Named", "details": "d", "clients": []string{"Forever"}, "clients_quote": "apply on Forever only"},
		map[string]any{"category": "Fixed", "title": "Guessed", "details": "d", "clients": []string{"Retail", "Classic"}, "clients_quote": "Login fix"},
	}})
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			io.WriteString(w, interaction("completed", string(draft)))
			return
		}
		w.WriteHeader(http.StatusBadRequest)
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)
	s, err := g.Summarize(context.Background(), commits)
	if err != nil || s.Headline != "Draft." || len(s.Entries) != 2 {
		t.Fatalf("summary %+v, %v", s, err)
	}
	if strings.Join(s.Entries[0].Clients, ",") != "Forever" || len(s.Entries[1].Clients) != 0 {
		t.Errorf("clients %v and %v", s.Entries[0].Clients, s.Entries[1].Clients)
	}
}

// Every entry Gemini writes carries its clients' quote, in the draft and in the review.
func TestTheNotesAskForTheClientsQuote(t *testing.T) {
	for name, schema := range map[string]map[string]any{"draft": summarySchema, "review": reviewSchema} {
		entries, _ := schema["properties"].(map[string]any)["entries"].(map[string]any)
		item, _ := entries["items"].(map[string]any)
		required, _ := item["required"].([]string)
		if strings.Join(required, ",") != "category,title,details,clients,clients_quote" {
			t.Errorf("%s: an entry requires %v", name, required)
		}
		if _, ok := item["properties"].(map[string]any)["clients_quote"]; !ok {
			t.Errorf("%s: an entry has no clients_quote", name)
		}
	}
	for _, rule := range []string{"clients_quote", "copied exactly", "Never work out from what you know of the game", "name those versions and no others"} {
		if !strings.Contains(systemInstruction, rule) {
			t.Errorf("system instruction lacks %q", rule)
		}
	}
}

// Each word the commits use for a client names it, alone and as a whole word.
func TestEachClientWordNamesItsClient(t *testing.T) {
	words := map[string]string{
		"retail": "Retail", "mainline": "Retail",
		"classic": "Classic", "era": "Classic", "vanilla": "Classic", "tbc": "Classic", "burning crusade": "Classic",
		"wrath": "Classic", "cataclysm": "Classic", "mists": "Classic", "mop": "Classic", "anniversary": "Classic",
		"forever": "Forever", "camelot": "Forever",
	}
	for word, client := range words {
		quote := "it opens on " + word + " only"
		for c, pattern := range clientNamed {
			if pattern.MatchString(quote) != (c == client) {
				t.Errorf("%q names %s: %v", word, c, pattern.MatchString(quote))
			}
		}
	}
	for _, quote := range []string{"several", "operations", "moped", "detailed", "foreverything"} {
		for c, pattern := range clientNamed {
			if pattern.MatchString(quote) {
				t.Errorf("%q names %s", quote, c)
			}
		}
	}
}
