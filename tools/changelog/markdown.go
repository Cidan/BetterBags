package main

import (
	"bufio"
	"io"
	"os"
	"regexp"
	"strings"
)

// The Markdown changelog is the packager's manual changelog (.pkgmeta manual-changelog): the text
// CurseForge, Wago, WoWInterface and the GitHub release show for a build, instead of the commit log.
// It holds the build's own notes only.

// markdownSections are the headings of the categories, in the order they are listed.
var markdownSections = []struct{ category, heading string }{
	{"New", "New"},
	{"Improved", "Improved"},
	{"Fixed", "Fixed"},
	{"Changed", "Changes"},
}

var markdownClientNames = map[string]string{"Retail": "Retail", "Classic": "Classic", "Forever": "WoW: Forever"}

var markdownSpecial = strings.NewReplacer(
	`\`, `\\`, "`", "\\`", `*`, `\*`, `_`, `\_`, `[`, `\[`, `]`, `\]`, `<`, `\<`, `>`, `\>`, `|`, `\|`,
)

var leadingNumber = regexp.MustCompile(`^(\d+)([.)])`)

// markdownText escapes notes text for Markdown. The notes double "|" for the game (cleanText);
// Markdown gets it single, escaped. A line that would start a heading, a list or a numbered list
// is escaped too.
func markdownText(s string) string {
	s = markdownSpecial.Replace(strings.ReplaceAll(s, "||", "|"))
	if strings.HasPrefix(s, "#") || strings.HasPrefix(s, "-") || strings.HasPrefix(s, "+") {
		s = `\` + s
	}
	return leadingNumber.ReplaceAllString(s, `$1\$2`)
}

// clientNote names the clients an entry applies to, when it does not apply to every one.
func clientNote(clients []string) string {
	if len(clients) == 0 || len(clients) >= len(clientNames) {
		return ""
	}
	names := make([]string, 0, len(clients))
	for _, c := range clients {
		if name, ok := markdownClientNames[c]; ok {
			names = append(names, name)
		}
	}
	if len(names) == 0 {
		return ""
	}
	if len(names) == 1 {
		return " (" + names[0] + " only)"
	}
	return " (" + strings.Join(names[:len(names)-1], ", ") + " and " + names[len(names)-1] + " only)"
}

// WriteMarkdown writes a build's notes: its headline, then its entries under a heading per
// category.
func WriteMarkdown(w io.Writer, r Release) error {
	out := bufio.NewWriter(w)
	out.WriteString(markdownText(r.Headline) + "\n")
	for _, section := range markdownSections {
		var lines []string
		for _, e := range r.Entries {
			category := e.Category
			if category != "New" && category != "Improved" && category != "Fixed" {
				category = "Changed"
			}
			if category != section.category {
				continue
			}
			line := "- **" + markdownText(e.Title) + "**" + clientNote(e.Clients)
			if e.Details != "" {
				line += ": " + markdownText(e.Details)
			}
			lines = append(lines, line)
		}
		if len(lines) == 0 {
			continue
		}
		out.WriteString("\n## " + section.heading + "\n\n")
		for _, line := range lines {
			out.WriteString(line + "\n")
		}
	}
	return out.Flush()
}

// writeMarkdown writes a build's notes to path.
func writeMarkdown(path string, r Release) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	if err := WriteMarkdown(f, r); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}
