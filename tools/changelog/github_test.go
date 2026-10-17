package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestPullsForCommitReadsEachPullRequestsCommits(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer gh-token" || r.Header.Get("Accept") != "application/vnd.github+json" {
			t.Errorf("headers %v", r.Header)
		}
		switch r.URL.Path {
		case "/repos/Cidan/BetterBags/commits/abc/pulls":
			io.WriteString(w, `[{"number":1144,"title":"Forever free slots","body":"The body."}]`)
		case "/repos/Cidan/BetterBags/pulls/1144/commits":
			if r.URL.Query().Get("per_page") != "100" {
				t.Errorf("query %v", r.URL.Query())
			}
			io.WriteString(w, `[{"sha":"c1","commit":{"message":"Render recorder\n\nRecords buttons."}},{"sha":"c2","commit":{"message":"Free slots"}}]`)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()
	gh := &GitHubClient{BaseURL: server.URL, Repo: "Cidan/BetterBags", Token: "gh-token", HTTP: &http.Client{Timeout: 5 * time.Second}}

	pulls, err := gh.PullsForCommit("abc")
	if err != nil {
		t.Fatalf("PullsForCommit: %v", err)
	}
	if len(pulls) != 1 || pulls[0].Number != 1144 || pulls[0].Title != "Forever free slots" {
		t.Fatalf("pulls = %+v", pulls)
	}
	commits := pulls[0].Commits
	if len(commits) != 2 || commits[0] != (Commit{SHA: "c1", Subject: "Render recorder", Body: "Records buttons."}) || commits[1].Subject != "Free slots" {
		t.Errorf("commits = %+v", commits)
	}
}

func TestPullsForCommitFailsOnAnError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer server.Close()
	gh := &GitHubClient{BaseURL: server.URL, Repo: "Cidan/BetterBags", HTTP: &http.Client{Timeout: 5 * time.Second}}
	if _, err := gh.PullsForCommit("abc"); err == nil {
		t.Errorf("no error")
	}
}
