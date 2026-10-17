#!/usr/bin/env bash
# Checks out and saves the changelog branch, where tools/changelog keeps every build's notes
# (releases/<version>.json). Run from the repository's checkout in CI:
#
#   store.sh checkout <dir>          a worktree of origin/changelog (a new, empty branch the first time)
#   store.sh save <dir> <message>    commit what changed under releases/ and push it
#
# Builds can run at once; each writes its own version's file, so a push that loses the race
# rebases onto the other build's notes, keeping its own, and tries again.
set -euo pipefail

branch=changelog
command=${1:?checkout or save}
dir=${2:?a directory}

case "$command" in
checkout)
  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    git fetch --quiet origin "+refs/heads/$branch:refs/remotes/origin/$branch"
    git worktree add --quiet --detach "$dir" "origin/$branch"
  else
    git worktree add --quiet --detach "$dir"
    git -C "$dir" checkout --quiet --orphan "$branch"
    git -C "$dir" rm -r --quiet --force --cached .
    git -C "$dir" clean -d --quiet --force
  fi
  ;;
save)
  message=${3:?a commit message}
  mkdir -p "$dir/releases"
  git -C "$dir" add -A releases
  if git -C "$dir" diff --cached --quiet; then
    echo "changelog: no new notes to save"
    exit 0
  fi
  git -C "$dir" -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "$message"
  for attempt in 1 2 3 4 5; do
    if git -C "$dir" push --quiet origin "HEAD:refs/heads/$branch"; then
      exit 0
    fi
    git -C "$dir" fetch --quiet origin "+refs/heads/$branch:refs/remotes/origin/$branch"
    # In a rebase, "theirs" is the commit being replayed: this build's notes win a conflict.
    git -C "$dir" -c user.name="github-actions[bot]" \
      -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      rebase --quiet -X theirs "origin/$branch"
    sleep "$attempt"
  done
  echo "changelog: could not push the notes" >&2
  exit 1
  ;;
*)
  echo "usage: store.sh checkout <dir> | save <dir> <message>" >&2
  exit 2
  ;;
esac
