package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// DefaultGeminiURL is the Gemini API (Google AI Studio keys).
const DefaultGeminiURL = "https://generativelanguage.googleapis.com"

// DefaultGeminiModel is the model that writes the notes.
const DefaultGeminiModel = "gemini-3.8-flash"

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

You are given the commit messages of one build: every change merged since the previous build. A commit can come with the commits of the pull request it merged. Write the notes for players, in plain language, describing how this build differs from the previous one:

- Group related commits into a single entry. Commits often build on, fix or revert each other; describe the end result once, never one entry per commit.
- A feature that is new in this build is one New entry describing it as it ships. Changes and fixes made to it within this build are part of that entry, never as separate Improved or Fixed entries: players never saw the earlier versions. Improved and Fixed are only for things that existed before this build.
- Never say the same thing twice. When several commits fix or describe the same problem, even in different words, or one commit fixes several things other commits also mention, write each change once, in one entry.
- Leave out what players cannot notice: tests, CI, refactors, documentation, code comments and developer tooling, unless it changes or fixes something they see.
- category: "New" for a feature, "Improved" for a feature that works better, "Fixed" for a bug fixed.
- title: what changed, at most 60 characters, no period at the end.
- details: one to three sentences on what players will notice.
- clients: the game versions an entry applies to, only when it does not apply to all of them: "Retail" (the live game), "Classic" (Classic Era, Burning Crusade, Mists and the other classic versions) and "Forever" (WoW: Forever; the code calls it Camelot). An empty list means every version.
- headline: one sentence summing up the build.
- Plain text only: no markdown, no links, no commit hashes, no issue or pull request numbers, no file or function names, and never the "|" character.
- If nothing in the build affects players, return no entries and a headline saying the build has only behind-the-scenes changes.`

// summarySchema is the JSON schema the notes must match.
var summarySchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"headline": map[string]any{"type": "string", "description": "One sentence summing up the build."},
		"entries": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"category": map[string]any{"type": "string", "enum": []string{"New", "Improved", "Fixed"}},
					"title":    map[string]any{"type": "string", "description": "What changed, at most 60 characters."},
					"details":  map[string]any{"type": "string", "description": "One to three sentences on what players will notice."},
					"clients": map[string]any{
						"type":  "array",
						"items": map[string]any{"type": "string", "enum": []string{"Retail", "Classic", "Forever"}},
					},
				},
				"required": []string{"category", "title", "details", "clients"},
			},
		},
	},
	"required": []string{"headline", "entries"},
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

// retryable is an error worth another attempt: the server was busy or failed, or its answer
// could not be used.
type retryable struct{ err error }

func (r retryable) Error() string { return r.err.Error() }
func (r retryable) Unwrap() error { return r.err }

// reviewInput asks Gemini to check its draft of a build's notes against the commits.
func reviewInput(input string, draft Summary) string {
	data, _ := json.MarshalIndent(draft, "", "  ")
	return `Below are a build's commit messages and a draft of its notes. Check the draft against the rules and return the corrected notes:
- Every feature that is new in this build is one New entry. Remove each Improved or Fixed entry about changing or fixing it, folding anything players will notice into the New entry.
- Merge entries that describe the same change or the same fix, even in different words, so nothing is said twice.
- Remove entries about what players cannot notice.
- Keep every remaining fact accurate to the commits, and add nothing they do not say.

=== The commits
` + input + `

=== The draft
` + string(data) + "\n"
}

// Summarize asks Gemini for a build's notes, then asks it to review that draft against the
// commits (folding iterations on new features into them, merging repeats). A review that fails
// leaves the draft.
func (g *Gemini) Summarize(ctx context.Context, input string) (Summary, error) {
	draft, err := g.ask(ctx, input)
	if err != nil {
		return Summary{}, err
	}
	reviewed, err := g.ask(ctx, reviewInput(input, draft))
	if err != nil {
		if g.Log != nil {
			fmt.Fprintf(g.Log, "changelog: the review failed, keeping the draft: %v\n", err)
		}
		return draft, nil
	}
	return reviewed, nil
}

// ask runs one interaction, retrying a busy or failing server and an answer that does not
// match the schema.
func (g *Gemini) ask(ctx context.Context, input string) (Summary, error) {
	attempts := g.Attempts
	if attempts < 1 {
		attempts = 1
	}
	var err error
	for attempt := 1; attempt <= attempts; attempt++ {
		var s Summary
		s, err = g.summarizeOnce(ctx, input)
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

func (g *Gemini) summarizeOnce(ctx context.Context, input string) (Summary, error) {
	body, err := json.Marshal(interactionRequest{
		Model:             g.Model,
		SystemInstruction: systemInstruction,
		Input:             input,
		ResponseFormat:    responseFormat{Type: "text", MimeType: "application/json", Schema: summarySchema},
		GenerationConfig:  generationConfig{ThinkingLevel: "medium", MaxOutputTokens: 16384},
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
	var s Summary
	if err := json.Unmarshal([]byte(text), &s); err != nil {
		return Summary{}, retryable{fmt.Errorf("gemini: the notes are not JSON: %w", err)}
	}
	s, err = s.Validate()
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
