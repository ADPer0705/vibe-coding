#!/bin/bash

# update-submodules.sh
# Script to update git submodules and commit changes to the main repository
# This script should be run periodically or triggered by CI/CD to keep submodules in sync

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the script directory to ensure we're in the right place
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_status "Starting submodule update process..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository. Exiting."
    exit 1
fi

# Check if .gitmodules exists
if [ ! -f ".gitmodules" ]; then
    print_error "No .gitmodules file found. Exiting."
    exit 1
fi

# Store initial state
INITIAL_COMMIT=$(git rev-parse HEAD)
print_status "Initial commit: $INITIAL_COMMIT"

# Update all submodules to their latest commits on their respective branches
print_status "Updating submodules to latest commits..."

# Initialize submodules if they haven't been initialized
git submodule update --init --recursive

# Track changes
CHANGES_MADE=false
UPDATED_SUBMODULES=()

# Read each submodule and update it
while IFS= read -r line; do
    if [[ $line =~ ^\[submodule ]]; then
        # Extract submodule name
        SUBMODULE_NAME=$(echo "$line" | sed 's/\[submodule "\([^"]*\)"\]/\1/')
        continue
    fi
    
    if [[ $line =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+) ]]; then
        SUBMODULE_PATH="${BASH_REMATCH[1]}"
        
        if [ -d "$SUBMODULE_PATH" ]; then
            print_status "Processing submodule: $SUBMODULE_NAME at $SUBMODULE_PATH"
            
            cd "$SUBMODULE_PATH"
            
            # Store current commit
            OLD_COMMIT=$(git rev-parse HEAD)
            
            # Fetch latest changes
            print_status "Fetching latest changes for $SUBMODULE_NAME..."
            git fetch origin
            
            # Get the default branch name
            DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
            
            # Check if we're already on the latest commit
            LATEST_COMMIT=$(git rev-parse "origin/$DEFAULT_BRANCH")
            
            if [ "$OLD_COMMIT" != "$LATEST_COMMIT" ]; then
                print_status "Updating $SUBMODULE_NAME from $OLD_COMMIT to $LATEST_COMMIT"
                
                # Update to latest commit
                git checkout "$DEFAULT_BRANCH"
                git pull origin "$DEFAULT_BRANCH"
                
                CHANGES_MADE=true
                UPDATED_SUBMODULES+=("$SUBMODULE_NAME")
                
                print_success "Updated $SUBMODULE_NAME"
            else
                print_status "$SUBMODULE_NAME is already up to date"
            fi
            
            cd "$SCRIPT_DIR"
        else
            print_warning "Submodule directory not found: $SUBMODULE_PATH"
        fi
    fi
done < .gitmodules

# If changes were made, commit them
if [ "$CHANGES_MADE" = true ]; then
    print_status "Changes detected in submodules. Committing updates..."
    
    # Add all submodule changes
    git add .
    
    # Create commit message
    COMMIT_MSG="🔄 Update submodules

Updated submodules:
$(printf '• %s\n' "${UPDATED_SUBMODULES[@]}")

Auto-updated on $(date '+%Y-%m-%d %H:%M:%S %Z')"

    # Commit the changes
    git commit -m "$COMMIT_MSG"
    
    NEW_COMMIT=$(git rev-parse HEAD)
    print_success "Changes committed: $NEW_COMMIT"
    
    # Ask if user wants to push (for manual runs)
    if [ "${1:-}" != "--auto-push" ]; then
        read -p "Do you want to push the changes to remote? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin main
            print_success "Changes pushed to remote repository"
        else
            print_status "Changes committed locally but not pushed"
        fi
    else
        # Auto-push for CI/CD scenarios
        git push origin main
        print_success "Changes automatically pushed to remote repository"
    fi
    
else
    print_status "No submodule updates needed"
fi

print_success "Submodule update process completed!"
