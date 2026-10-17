package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// These run store.sh, the script CI checks out and saves the changelog branch with, against a
// bare repository standing in for origin.

func sh(t *testing.T, dir string, name string, args ...string) string {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=spec", "GIT_AUTHOR_EMAIL=spec@example.com",
		"GIT_COMMITTER_NAME=spec", "GIT_COMMITTER_EMAIL=spec@example.com",
		"GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s %s: %v\n%s", name, strings.Join(args, " "), err, out)
	}
	return string(out)
}

// clone makes a bare origin with one commit on main and clones it.
func clone(t *testing.T, origin string) string {
	t.Helper()
	dir := t.TempDir()
	sh(t, dir, "git", "clone", "--quiet", origin, "work")
	return filepath.Join(dir, "work")
}

func newOrigin(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	sh(t, root, "git", "init", "--quiet", "--bare", "--initial-branch=main", origin)
	seed := filepath.Join(root, "seed")
	sh(t, root, "git", "init", "--quiet", "--initial-branch=main", seed)
	os.WriteFile(filepath.Join(seed, "addon.lua"), []byte("-- addon\n"), 0o644)
	sh(t, seed, "git", "add", "addon.lua")
	sh(t, seed, "git", "commit", "--quiet", "-m", "addon")
	sh(t, seed, "git", "push", "--quiet", origin, "main")
	return origin
}

func script(t *testing.T) string {
	t.Helper()
	path, err := filepath.Abs("store.sh")
	if err != nil {
		t.Fatal(err)
	}
	return path
}

func writeRelease(t *testing.T, store, name, body string) {
	t.Helper()
	os.MkdirAll(filepath.Join(store, "releases"), 0o755)
	if err := os.WriteFile(filepath.Join(store, "releases", name), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestStoreScriptStartsTheBranchAndSavesToIt(t *testing.T) {
	origin := newOrigin(t)
	work := clone(t, origin)
	store := filepath.Join(t.TempDir(), "store")

	sh(t, work, "bash", script(t), "checkout", store)
	entries, _ := os.ReadDir(store)
	for _, e := range entries {
		if e.Name() != ".git" {
			t.Errorf("a new branch starts empty, found %s", e.Name())
		}
	}
	writeRelease(t, store, "v1.json", "{}\n")
	sh(t, work, "bash", script(t), "save", store, "Notes for v1")

	files := sh(t, work, "git", "--git-dir", origin, "ls-tree", "-r", "--name-only", "changelog")
	if strings.TrimSpace(files) != "releases/v1.json" {
		t.Errorf("origin's changelog branch holds %q", files)
	}
	if log := sh(t, work, "git", "--git-dir", origin, "log", "--format=%s", "changelog"); strings.TrimSpace(log) != "Notes for v1" {
		t.Errorf("log %q", log)
	}
	if main := sh(t, work, "git", "status", "--porcelain"); main != "" {
		t.Errorf("the checkout changed the working tree: %q", main)
	}
}

func TestStoreScriptChecksOutTheStoredNotes(t *testing.T) {
	origin := newOrigin(t)
	first := clone(t, origin)
	store := filepath.Join(t.TempDir(), "store")
	sh(t, first, "bash", script(t), "checkout", store)
	writeRelease(t, store, "v1.json", "{\"id\":1}\n")
	sh(t, first, "bash", script(t), "save", store, "v1")

	second := clone(t, origin)
	again := filepath.Join(t.TempDir(), "store")
	sh(t, second, "bash", script(t), "checkout", again)
	data, err := os.ReadFile(filepath.Join(again, "releases", "v1.json"))
	if err != nil || string(data) != "{\"id\":1}\n" {
		t.Errorf("checked out %q, %v", data, err)
	}
}

func TestStoreScriptSavesNothingWhenNothingChanged(t *testing.T) {
	origin := newOrigin(t)
	work := clone(t, origin)
	store := filepath.Join(t.TempDir(), "store")
	sh(t, work, "bash", script(t), "checkout", store)
	writeRelease(t, store, "v1.json", "{}\n")
	sh(t, work, "bash", script(t), "save", store, "v1")
	sh(t, work, "bash", script(t), "save", store, "again")
	if log := sh(t, work, "git", "--git-dir", origin, "log", "--format=%s", "changelog"); strings.TrimSpace(log) != "v1" {
		t.Errorf("log %q", log)
	}
}

// Two builds that ran at once each save their own version's notes: the second rebases onto the
// first and pushes.
func TestStoreScriptSavesAfterAnotherBuildSaved(t *testing.T) {
	origin := newOrigin(t)
	seedWork := clone(t, origin)
	seedStore := filepath.Join(t.TempDir(), "store")
	sh(t, seedWork, "bash", script(t), "checkout", seedStore)
	writeRelease(t, seedStore, "v1.json", "{}\n")
	sh(t, seedWork, "bash", script(t), "save", seedStore, "v1")

	a, b := clone(t, origin), clone(t, origin)
	storeA, storeB := filepath.Join(t.TempDir(), "a"), filepath.Join(t.TempDir(), "b")
	sh(t, a, "bash", script(t), "checkout", storeA)
	sh(t, b, "bash", script(t), "checkout", storeB)
	writeRelease(t, storeA, "v2-1.json", "{\"build\":\"a\"}\n")
	writeRelease(t, storeB, "v2-2.json", "{\"build\":\"b\"}\n")
	sh(t, a, "bash", script(t), "save", storeA, "a")
	sh(t, b, "bash", script(t), "save", storeB, "b")

	files := strings.Fields(sh(t, a, "git", "--git-dir", origin, "ls-tree", "-r", "--name-only", "changelog"))
	if strings.Join(files, ",") != "releases/v1.json,releases/v2-1.json,releases/v2-2.json" {
		t.Errorf("origin holds %v", files)
	}
}
