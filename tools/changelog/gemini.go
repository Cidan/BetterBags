package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
)

// DefaultGeminiURL is the Gemini API (Google AI Studio keys).
const DefaultGeminiURL = "https://generativelanguage.googleapis.com"

// DefaultGeminiModel is the model that writes the notes.
const DefaultGeminiModel = "gemini-4-hydrogen"

const (
	// thinkingLevel is Hydrogen's own default.
	thinkingLevel = "high"
	// maxOutputTokens counts the model's thinking as well as the notes: Hydrogen's limit for one
	// synchronous answer.
	maxOutputTokens = 65536
)

// Summarizer writes a build's notes from its commit messages.
type Summarizer interface {
	Summarize(ctx context.Context, input string) (Summary, error)
}

// Gemini writes notes with the Gemini API's Interactions endpoint
// (POST /v1beta/interactions), asking for JSON that matches summarySchema.
type Gemini struct {
	BaseURL  string
	Key      string
	Model    string
	HTTP     *http.Client
	Attempts int
	Sleep    func(time.Duration)
	// Log reports a review that failed (the draft is kept); nil reports nothing.
	Log io.Writer
}

// systemInstruction tells Gemini who the notes are for and how to write them.
const systemInstruction = `You write the in-game changelog of BetterBags, a bag addon for World of Warcraft.

You are given the commit messages of one build: every change merged since the previous build. A commit can come with the commits of the pull request it merged. Developers wrote them for developers: they explain causes, code, tests and reviews at length. Write the notes for players, in a literal, precise technical register, describing how this build differs from the previous one.

What to cover:
- Every change a player can notice gets into the notes: a new feature, setting or option (say where to find it), a change to how something looks or works, a changed default, a change to what a player's existing setup does once they update, a button or control that was removed or replaced (say where its job is now), and every bug fixed. A build with many changes has many entries.
- Leave out what players cannot notice: tests, CI, refactors, documentation, code comments, debugging and profiling tools, and developer tooling. Leave out changes outside the addon too, such as the issue tracker's forms or the repository.
- A commit message often lists what its bug reviews, tests or later commits found wrong in the commit's own change and fixed before it was merged. Players never had those problems: they are part of the change as it ships, never entries of their own. A bug is a Fixed entry only when the commits say players had it: it was reported, seen in game, or there since an earlier build.
- Describe what players see and do, never how the code does it: no causes in code terms, no names of modules, functions, files, events or saved variables. When the commits do not make clear what a player would see, leave the change out rather than guess.

How to group:
- One entry per change a player would look for. Never put unrelated changes in one entry because they came in the same commit: a commit that does several things (its subject lists them, or its pull request's commits do different things) gives several entries.
- Changes to the same feature go in one entry. Commits often build on, fix or revert each other; describe the end result once.
- A feature that is new in this build is one New entry describing it as it ships. Changes and fixes made to it within this build are part of that entry, never as separate Improved or Fixed entries: players never saw the earlier versions. Improved and Fixed are only for things that existed before this build.
- Never say the same thing twice. When several commits fix or describe the same problem, even in different words, or one commit fixes several things other commits also mention, write each change once, in one entry. A new feature that also changes something players already had describes that change in its own entry or in one entry of its own, never in both.

Accuracy:
- Say only what the commits say. Never guess at a number, a name, where a setting is or how something works.
- clients: the game versions an entry applies to, only when it does not apply to all of them: "Retail" (the live game), "Classic" (Classic Era, Burning Crusade, Mists and the other classic versions) and "Forever" (WoW: Forever; the code calls it Camelot). Name versions only when the commits name them: they say the change is limited to those versions, or that it is about something only those versions have. Never work out from what you know of the game which versions have something. A change reported from one version applies to every version unless the commits say otherwise. An empty list means every version.
- clients_quote: when clients is not empty, the words of the commits, copied exactly, that name those versions and no others; empty otherwise. An entry whose quote is not in the commits, or does not name exactly its versions, applies to every version.

Style:
- Write in a literal, precise technical register: name exactly what changed, where it is and what it does.
- Never write that BetterBags, a window, bag, tab, section, setting, category or item holds, keeps, knows, remembers, wants, asks, waits, learns, decides, tries or refuses anything: say what it contains, displays, matches, stores or rejects. The player is the only one with intentions: "hold Shift" and "choose a category" are correct.
- No colloquialisms and no casual metaphors (gets, takes, handles, kicks in).

The fields:
- category: "New" for a feature, setting or option players did not have before; "Improved" for something that existed and now works, looks or behaves better or differently; "Fixed" for something that did not work as it should and now does.
- title: what changed, at most 60 characters, no period at the end.
- details: what players will notice, in one to three short sentences, at most 300 characters: the main point first, and only the particulars a player needs.
- headline: one short sentence summing up the build's most notable changes, without its version number.
- List the New entries first, then Improved, then Fixed, the most notable first in each.
- Plain text only: no markdown, no links, no commit hashes, no issue or pull request numbers, and never the "|" character.
- If nothing in the build affects players, return no entries and a headline saying the build has only behind-the-scenes changes.`

// summarySchema is the JSON schema the notes must match.
var summarySchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"headline": map[string]any{"type": "string", "description": "One short sentence summing up the build."},
		"entries": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"category": map[string]any{"type": "string", "enum": []string{"New", "Improved", "Fixed"}},
					"title":    map[string]any{"type": "string", "description": "What changed, at most 60 characters."},
					"details":  map[string]any{"type": "string", "description": "What players will notice, in one to three short sentences."},
					"clients": map[string]any{
						"type":  "array",
						"items": map[string]any{"type": "string", "enum": []string{"Retail", "Classic", "Forever"}},
					},
					"clients_quote": map[string]any{"type": "string", "description": "When clients is not empty, the words of the commits, copied exactly, that name those versions; empty otherwise."},
				},
				"required": []string{"category", "title", "details", "clients", "clients_quote"},
			},
		},
	},
	"required": []string{"headline", "entries"},
}

// reviewSchema is the notes' schema with the review's audit first: each change in the list, what
// players notice of it, and the entries that cover it. Only the notes are kept.
var reviewSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"coverage": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"change":  map[string]any{"type": "integer", "description": "The change's number in the list."},
					"notice":  map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "What players will notice of it; empty when they notice nothing."},
					"entries": map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "The titles of the entries that cover it."},
				},
				"required": []string{"change", "notice", "entries"},
			},
		},
		"headline": summarySchema["properties"].(map[string]any)["headline"],
		"entries":  summarySchema["properties"].(map[string]any)["entries"],
	},
	"required": []string{"coverage", "headline", "entries"},
}

type interactionRequest struct {
	Model             string           `json:"model"`
	SystemInstruction string           `json:"system_instruction"`
	Input             string           `json:"input"`
	ResponseFormat    responseFormat   `json:"response_format"`
	GenerationConfig  generationConfig `json:"generation_config"`
	Store             bool             `json:"store"`
}

type responseFormat struct {
	Type     string         `json:"type"`
	MimeType string         `json:"mime_type"`
	Schema   map[string]any `json:"schema"`
}

type generationConfig struct {
	ThinkingLevel   string `json:"thinking_level"`
	MaxOutputTokens int    `json:"max_output_tokens"`
}

type interactionResponse struct {
	Status string `json:"status"`
	Steps  []struct {
		Type    string `json:"type"`
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	} `json:"steps"`
}

// geminiNotes is the notes as Gemini writes them: each entry with the commits' words that limit it to
// its clients.
type geminiNotes struct {
	Headline string `json:"headline"`
	Entries  []struct {
		Entry
		ClientsQuote string `json:"clients_quote"`
	} `json:"entries"`
}

// clientNamed matches the words that name each client in the commits, as whole words.
var clientNamed = map[string]*regexp.Regexp{
	"Retail":  regexp.MustCompile(`\b(retail|mainline)\b`),
	"Classic": regexp.MustCompile(`\b(classic|era|vanilla|tbc|burning crusade|wrath|cataclysm|mists|mop|anniversary)\b`),
	"Forever": regexp.MustCompile(`\b(forever|camelot)\b`),
}

var plainQuotes = strings.NewReplacer("‘", "'", "’", "'", "“", `"`, "”", `"`)

// folded is text as quotes are compared: plain quote marks, one space between words, lower case.
func folded(s string) string {
	return strings.ToLower(strings.Join(strings.Fields(plainQuotes.Replace(s)), " "))
}

// summary is the notes, each entry keeping its clients only when its quote is in the commits and
// names exactly those clients; otherwise the entry applies to every client. The in-game window
// hides an entry from the other clients, so a client guessed hides a change from players who have
// it.
func (w geminiNotes) summary(commits string) Summary {
	s := Summary{Headline: w.Headline, Entries: []Entry{}}
	all := folded(commits)
	for _, e := range w.Entries {
		entry := e.Entry
		quote := strings.Trim(folded(e.ClientsQuote), ` "'`)
		named := quote != "" && strings.Contains(all, quote)
		listed := map[string]bool{}
		for _, c := range entry.Clients {
			listed[c] = true
		}
		for c, pattern := range clientNamed {
			if pattern.MatchString(quote) != listed[c] {
				named = false
			}
		}
		if !named {
			entry.Clients = []string{}
		}
		s.Entries = append(s.Entries, entry)
	}
	return s
}

// retryable is an error worth another attempt: the server was busy or failed, or its answer
// could not be used.
type retryable struct{ err error }

func (r retryable) Error() string { return r.err.Error() }
func (r retryable) Unwrap() error { return r.err }

// reviewInput asks Gemini to check its draft of a build's notes against the commits, accounting
// for every change ChangeList finds in them.
func reviewInput(input string, draft Summary) string {
	data, _ := json.MarshalIndent(draft, "", "  ")
	var list strings.Builder
	for i, change := range ChangeList(input) {
		fmt.Fprintf(&list, "%d. %s\n", i+1, change)
	}
	return `Below are a build's commit messages, the list of every commit and pull request commit in them, and a draft of its notes. Check the draft against the rules and return the complete corrected notes:
- Coverage: for every change in the list, in order, read its message and give in coverage what players will notice of it (nothing for what they cannot notice, or for a fix to the change's own work before players had it) and the entries that cover that. Add an entry, or add to the entry it belongs in, for everything the draft leaves out.
- Every feature that is new in this build is one New entry. Remove each Improved or Fixed entry about changing or fixing it, folding anything players will notice into the New entry.
- Remove each Fixed entry for a problem a commit's own review, tests or a later commit fixed before players had it.
- Split an entry that puts unrelated changes together.
- Merge entries that describe the same change or the same fix, even in different words, so nothing is said twice.
- Remove entries about what players cannot notice, and code-level detail from the rest.
- Check every fact and every client list against the commits: correct or remove what they do not say.

=== The commits
` + input + `

=== The changes to account for
` + list.String() + `
=== The draft
` + string(data) + "\n"
}

// Summarize asks Gemini for a build's notes, then asks it to review that draft against the
// commits (every change accounted for, iterations on new features folded into them, repeats
// merged). A review that fails leaves the draft.
func (g *Gemini) Summarize(ctx context.Context, input string) (Summary, error) {
	draft, err := g.ask(ctx, input, input, summarySchema)
	if err != nil {
		return Summary{}, err
	}
	reviewed, err := g.ask(ctx, reviewInput(input, draft), input, reviewSchema)
	if err != nil {
		if g.Log != nil {
			fmt.Fprintf(g.Log, "changelog: the review failed, keeping the draft: %v\n", err)
		}
		return draft, nil
	}
	return reviewed, nil
}

// ask runs one interaction, retrying a busy or failing server and an answer that does not
// match the schema. Clients are checked against commits, the build's commit messages.
func (g *Gemini) ask(ctx context.Context, input, commits string, schema map[string]any) (Summary, error) {
	attempts := g.Attempts
	if attempts < 1 {
		attempts = 1
	}
	var err error
	for attempt := 1; attempt <= attempts; attempt++ {
		var s Summary
		s, err = g.summarizeOnce(ctx, input, commits, schema)
		if err == nil {
			return s, nil
		}
		var again retryable
		if !errors.As(err, &again) || attempt == attempts {
			break
		}
		if g.Sleep != nil {
			g.Sleep(time.Duration(attempt*attempt) * 4 * time.Second)
		}
	}
	return Summary{}, err
}

func (g *Gemini) summarizeOnce(ctx context.Context, input, commits string, schema map[string]any) (Summary, error) {
	body, err := json.Marshal(interactionRequest{
		Model:             g.Model,
		SystemInstruction: systemInstruction,
		Input:             input,
		ResponseFormat:    responseFormat{Type: "text", MimeType: "application/json", Schema: schema},
		GenerationConfig:  generationConfig{ThinkingLevel: thinkingLevel, MaxOutputTokens: maxOutputTokens},
		Store:             false,
	})
	if err != nil {
		return Summary{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(g.BaseURL, "/")+"/v1beta/interactions", bytes.NewReader(body))
	if err != nil {
		return Summary{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", g.Key)
	resp, err := g.HTTP.Do(req)
	if err != nil {
		return Summary{}, retryable{fmt.Errorf("gemini: %w", err)}
	}
	defer resp.Body.Close()
	reply, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return Summary{}, retryable{fmt.Errorf("gemini: reading the reply: %w", err)}
	}
	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("gemini: %s: %s", resp.Status, truncate(string(reply), 500))
		if resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500 {
			return Summary{}, retryable{err}
		}
		return Summary{}, err
	}
	var parsed interactionResponse
	if err := json.Unmarshal(reply, &parsed); err != nil {
		return Summary{}, retryable{fmt.Errorf("gemini: the reply is not JSON: %w", err)}
	}
	if parsed.Status != "completed" {
		return Summary{}, retryable{fmt.Errorf("gemini: the interaction is %q", parsed.Status)}
	}
	text, found := "", false
	for _, step := range parsed.Steps {
		if step.Type != "model_output" {
			continue
		}
		found = true
		text = ""
		for _, c := range step.Content {
			if c.Type == "text" {
				text += c.Text
			}
		}
	}
	if !found {
		return Summary{}, retryable{errors.New("gemini: the reply has no model output")}
	}
	var w geminiNotes
	if err := json.Unmarshal([]byte(text), &w); err != nil {
		return Summary{}, retryable{fmt.Errorf("gemini: the notes are not JSON: %w", err)}
	}
	s, err := w.summary(commits).Validate()
	if err != nil {
		return Summary{}, retryable{fmt.Errorf("gemini: %w", err)}
	}
	return s, nil
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "..."
}
