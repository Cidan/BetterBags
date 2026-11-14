package main

import (
	"testing"
	"time"
)

// The slowest Gemini request measured took 97 s (the review of v0.8.0's notes, thinking at high);
// a request is given three times that, and a run holds a draft and a review at full length.
func TestARequestHasTimeForTheSlowestReview(t *testing.T) {
	if requestTimeout < 3*97*time.Second {
		t.Errorf("requestTimeout %s", requestTimeout)
	}
	if runTimeout < 2*requestTimeout {
		t.Errorf("runTimeout %s holds no draft and review of %s each", runTimeout, requestTimeout)
	}
}
