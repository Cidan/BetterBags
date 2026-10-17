package main

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Store keeps every build's notes, one JSON file per version under releases/, in a checkout of
// the changelog branch. Notes are written once and reused, so building a version again ships the
// same text.
type Store struct {
	Dir string
}

var unsafeName = regexp.MustCompile(`[^A-Za-z0-9._-]`)

func fileName(version string) string {
	return unsafeName.ReplaceAllString(strings.ReplaceAll(version, "/", "_"), "_") + ".json"
}

// Load returns every stored release, oldest first.
func (s Store) Load() ([]Release, error) {
	files, err := filepath.Glob(filepath.Join(s.Dir, "releases", "*.json"))
	if err != nil {
		return nil, err
	}
	var releases []Release
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			if errors.Is(err, fs.ErrNotExist) {
				continue
			}
			return nil, err
		}
		var r Release
		if err := json.Unmarshal(data, &r); err != nil {
			return nil, err
		}
		releases = append(releases, r)
	}
	sort.SliceStable(releases, func(i, j int) bool { return releases[i].ID < releases[j].ID })
	return releases, nil
}

// Save writes a release, replacing any stored under its version.
func (s Store) Save(r Release) error {
	dir := filepath.Join(s.Dir, "releases")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if r.Entries == nil {
		r.Entries = []Entry{}
	}
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, fileName(r.Version)), append(data, '\n'), 0o644)
}
