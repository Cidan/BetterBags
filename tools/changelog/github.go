package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

// DefaultGitHubURL is GitHub's REST API.
const DefaultGitHubURL = "https://api.github.com"

// PullRequest is a pull request a commit on main came from, with its own commits.
type PullRequest struct {
	Number  int
	Title   string
	Body    string
	Commits []Commit
}

// PullFinder finds the pull requests a commit came from.
type PullFinder interface {
	PullsForCommit(sha string) ([]PullRequest, error)
}

// GitHubClient reads pull requests with GitHub's REST API.
type GitHubClient struct {
	BaseURL string
	Repo    string
	Token   string
	HTTP    *http.Client
}

func (c *GitHubClient) get(path string, into any) error {
	req, err := http.NewRequest(http.MethodGet, strings.TrimRight(c.BaseURL, "/")+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("github %s: %s", path, resp.Status)
	}
	return json.Unmarshal(body, into)
}

// PullsForCommit returns the pull requests associated with a commit (for a squash merge, the
// one it merged), each with its commits (GitHub lists at most 250).
func (c *GitHubClient) PullsForCommit(sha string) ([]PullRequest, error) {
	var listed []struct {
		Number int    `json:"number"`
		Title  string `json:"title"`
		Body   string `json:"body"`
	}
	if err := c.get(fmt.Sprintf("/repos/%s/commits/%s/pulls", c.Repo, sha), &listed); err != nil {
		return nil, err
	}
	var pulls []PullRequest
	for _, p := range listed {
		var commits []struct {
			SHA    string `json:"sha"`
			Commit struct {
				Message string `json:"message"`
			} `json:"commit"`
		}
		if err := c.get(fmt.Sprintf("/repos/%s/pulls/%d/commits?per_page=100", c.Repo, p.Number), &commits); err != nil {
			return nil, err
		}
		pr := PullRequest{Number: p.Number, Title: p.Title, Body: p.Body}
		for _, commit := range commits {
			subject, body, _ := strings.Cut(commit.Commit.Message, "\n")
			pr.Commits = append(pr.Commits, Commit{SHA: commit.SHA, Subject: strings.TrimSpace(subject), Body: strings.TrimSpace(body)})
		}
		pulls = append(pulls, pr)
	}
	return pulls, nil
}
