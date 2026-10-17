package main

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Entry is one change in a release's notes, as the in-game changelog shows it.
type Entry struct {
	// Category is New, Improved or Fixed; Changed for notes listed from commits.
	Category string `json:"category"`
	Title    string `json:"title"`
	Details  string `json:"details"`
	// Clients are the game versions the change applies to (Retail, Classic, Forever); every
	// version when empty.
	Clients []string `json:"clients"`
}

// Summary is what Gemini writes for a build: a headline and the changes players will notice.
type Summary struct {
	Headline string  `json:"headline"`
	Entries  []Entry `json:"entries"`
}

// Release is a build's notes as kept on the changelog branch and bundled into the addon.
type Release struct {
	// ID orders releases; the in-game seen state compares it. It is the time the notes were
	// first written, kept above every earlier release's.
	ID       int64   `json:"id"`
	Version  string  `json:"version"`
	Channel  string  `json:"channel"`
	Date     string  `json:"date"`
	From     string  `json:"from"`
	To       string  `json:"to"`
	Headline string  `json:"headline"`
	Entries  []Entry `json:"entries"`
	// Fallback marks notes listed from the commits because Gemini could not write them; a
	// later build writes them again.
	Fallback bool `json:"fallback,omitempty"`
}

const (
	maxHeadline = 300
	maxTitle    = 100
	maxDetails  = 1200
	maxEntries  = 40
)

var categories = map[string]bool{"New": true, "Improved": true, "Fixed": true}

var clientNames = []string{"Retail", "Classic", "Forever"}

const fallbackHeadline = "The changes in this build."

// cleanText makes text safe to show in game: valid UTF-8 on one line, without control
// characters, trimmed, cut to max runes, and with "|" doubled (the game reads a single "|"
// as the start of an escape sequence and draws "||" as "|").
func cleanText(s string, max int) string {
	s = strings.ToValidUTF8(s, "")
	s = strings.Map(func(r rune) rune {
		if r == '\n' || r == '\r' || r == '\t' {
			return ' '
		}
		if unicode.IsControl(r) {
			return -1
		}
		return r
	}, s)
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) > max {
		s = strings.TrimSpace(string([]rune(s)[:max-3])) + "..."
	}
	return strings.ReplaceAll(s, "|", "||")
}

// Validate checks a summary Gemini wrote and returns a cleaned copy.
func (s Summary) Validate() (Summary, error) {
	out := Summary{Headline: cleanText(s.Headline, maxHeadline), Entries: []Entry{}}
	if out.Headline == "" {
		return Summary{}, errors.New("the summary has no headline")
	}
	for i, e := range s.Entries {
		if i >= maxEntries {
			break
		}
		if !categories[e.Category] {
			return Summary{}, fmt.Errorf("entry %d has an unknown category %q", i+1, e.Category)
		}
		title := cleanText(e.Title, maxTitle)
		if title == "" {
			return Summary{}, fmt.Errorf("entry %d has no title", i+1)
		}
		clients := []string{}
		for _, name := range clientNames {
			for _, c := range e.Clients {
				if c == name {
					clients = append(clients, name)
					break
				}
			}
		}
		out.Entries = append(out.Entries, Entry{
			Category: e.Category,
			Title:    title,
			Details:  cleanText(e.Details, maxDetails),
			Clients:  clients,
		})
	}
	return out, nil
}

var pullReference = regexp.MustCompile(`\s*\(#\d+\)$`)

// FallbackSummary lists the commits' subjects, for when Gemini could not write the notes.
func FallbackSummary(commits []Commit) Summary {
	s := Summary{Headline: fallbackHeadline, Entries: []Entry{}}
	for _, c := range commits {
		if len(s.Entries) >= maxEntries {
			break
		}
		title := cleanText(pullReference.ReplaceAllString(strings.TrimSpace(c.Subject), ""), maxTitle)
		if title == "" {
			continue
		}
		s.Entries = append(s.Entries, Entry{Category: "Changed", Title: title, Details: "", Clients: []string{}})
	}
	return s
}
