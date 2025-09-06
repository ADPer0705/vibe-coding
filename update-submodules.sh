#!/bin/bash

# Use the current working directory as the meta-repo root
REPO_ROOT="$(pwd)"
cd "$REPO_ROOT" || exit

echo "Fetching latest changes in meta-repo..."
git fetch origin
git pull

echo "Updating all submodules to latest remote commits..."
git submodule update --remote --merge

echo "Adding submodule updates to meta-repo..."
git add .

COMMIT_MSG="Update submodules to latest commits"

# Check if there are staged changes
if git diff --cached --quiet; then
    echo "No submodule updates found. Meta-repo is up-to-date."
else
    git commit -m "$COMMIT_MSG"
    echo "Pushing updates to remote..."
    git push
fi

echo "All submodules are updated!"
