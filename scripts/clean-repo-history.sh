#!/usr/bin/env bash
# Clean repo history: one commit on main, you as sole author, no Co-authored-by.
# Run from repo root. Do one step at a time (copy-paste each block or uncomment and run).

set -e
cd "$(git rev-parse --show-toplevel)"

# ------------------------------------------------------------------------------
# Step 1: Create orphan branch (no history) and stage everything
# ------------------------------------------------------------------------------
# git checkout --orphan temp-main
# git add -A

# ------------------------------------------------------------------------------
# Step 2: Create single commit with you as author (no Cursor co-author)
# ------------------------------------------------------------------------------
# git commit -m "Initial commit" --author="Daniel Saad <dsaad68@gmail.com>"

# ------------------------------------------------------------------------------
# Step 3: Replace main with the new single-commit branch
# ------------------------------------------------------------------------------
# git branch -D main
# git branch -m main

# ------------------------------------------------------------------------------
# Step 4: Force push to origin (updates GitHub; old history is replaced)
# ------------------------------------------------------------------------------
# git push --force origin main

# ------------------------------------------------------------------------------
# Step 5 (only if commit still had Co-authored-by): Remove it and push again
# ------------------------------------------------------------------------------
# FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter 'grep -v "Co-authored-by:"' main
# git push --force origin main

# ------------------------------------------------------------------------------
# Step 6: Remove filter-branch backup ref (optional cleanup)
# ------------------------------------------------------------------------------
# git update-ref -d refs/original/refs/heads/main 2>/dev/null || true
