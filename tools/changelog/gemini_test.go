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
		Model:    "gemini-3.8-flash",
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
	if got["model"] != "gemini-3.8-flash" || got["input"] != "the commits" || got["store"] != false {
		t.Errorf("model, input, store = %v, %v, %v", got["model"], got["input"], got["store"])
	}
	instruction, _ := got["system_instruction"].(string)
	for _, rule := range []string{"BetterBags", "new in this build", "never as separate Improved or Fixed entries", "Never say the same thing twice"} {
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
	config, _ := got["generation_config"].(map[string]any)
	if config["thinking_level"] != "medium" {
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

const reviewedJSON = `{"headline":"Reviewed.","entries":[{"category":"New","title":"Themed tabs","details":"Tabs match the theme, and fit under every border.","clients":[]}]}`

// The draft is reviewed by a second interaction: the commits and the draft go in, and the notes
// that come back are the build's.
func TestSummarizeReviewsItsDraft(t *testing.T) {
	var inputs []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		raw, _ := io.ReadAll(r.Body)
		json.Unmarshal(raw, &body)
		input, _ := body["input"].(string)
		inputs = append(inputs, input)
		if _, ok := body["response_format"].(map[string]any)["schema"]; !ok {
			t.Errorf("request %d has no schema", len(inputs))
		}
		if len(inputs) == 1 {
			io.WriteString(w, interaction("completed", summaryJSON))
		} else {
			io.WriteString(w, interaction("completed", reviewedJSON))
		}
	}))
	defer server.Close()
	g, _ := newGemini(server.URL)

	s, err := g.Summarize(context.Background(), "=== Commit: Themed tabs\n=== Commit: Fix the tabs under borders")
	if err != nil {
		t.Fatalf("Summarize: %v", err)
	}
	if len(inputs) != 2 {
		t.Fatalf("%d interactions", len(inputs))
	}
	if s.Headline != "Reviewed." {
		t.Errorf("summary = %+v", s)
	}
	review := inputs[1]
	for _, want := range []string{"Fix the tabs under borders", `"title": "Themed tabs"`, "Tabs match the theme."} {
		if !strings.Contains(review, want) {
			t.Errorf("the review lacks %q:\n%s", want, review)
		}
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
