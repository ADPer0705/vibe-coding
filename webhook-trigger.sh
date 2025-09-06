#!/bin/bash

# webhook-trigger.sh
# Script to trigger submodule update via GitHub API
# This can be called from individual submodule repositories to trigger updates

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration - these should be set via environment variables or arguments
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_OWNER="${REPO_OWNER:-}"
REPO_NAME="${REPO_NAME:-}"
SUBMODULE_NAME="${1:-}"

# Function to show usage
show_usage() {
    echo "Usage: $0 <submodule_name> [repo_owner] [repo_name]"
    echo ""
    echo "Environment variables needed:"
    echo "  GITHUB_TOKEN    - GitHub personal access token"
    echo "  REPO_OWNER      - Repository owner (default: current repo owner)"
    echo "  REPO_NAME       - Repository name (default: current repo name)"
    echo ""
    echo "Example:"
    echo "  export GITHUB_TOKEN=your_token_here"
    echo "  $0 telegram-download-manager"
    echo ""
    echo "Or with all parameters:"
    echo "  $0 telegram-download-manager ADPer0705 vibe-coding"
}

# Parse command line arguments
if [ "$#" -lt 1 ]; then
    show_usage
    exit 1
fi

# Override repo details if provided as arguments
if [ "$#" -ge 2 ]; then
    REPO_OWNER="$2"
fi

if [ "$#" -ge 3 ]; then
    REPO_NAME="$3"
fi

# Try to auto-detect repository information if not provided
if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    if git remote get-url origin >/dev/null 2>&1; then
        REMOTE_URL=$(git remote get-url origin)
        
        # Parse GitHub SSH URL format: git@github.com:owner/repo.git
        if [[ $REMOTE_URL =~ git@github\.com:([^/]+)/([^.]+)\.git ]]; then
            REPO_OWNER="${BASH_REMATCH[1]}"
            REPO_NAME="${BASH_REMATCH[2]}"
        # Parse GitHub HTTPS URL format: https://github.com/owner/repo.git
        elif [[ $REMOTE_URL =~ https://github\.com/([^/]+)/([^.]+)\.git ]]; then
            REPO_OWNER="${BASH_REMATCH[1]}"
            REPO_NAME="${BASH_REMATCH[2]}"
        fi
    fi
fi

# Validate required parameters
if [ -z "$GITHUB_TOKEN" ]; then
    print_error "GITHUB_TOKEN environment variable is required"
    show_usage
    exit 1
fi

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    print_error "Could not determine repository owner and name"
    show_usage
    exit 1
fi

print_status "Triggering submodule update for: $SUBMODULE_NAME"
print_status "Target repository: $REPO_OWNER/$REPO_NAME"

# Create the webhook payload
PAYLOAD=$(cat << EOF
{
  "event_type": "submodule-updated",
  "client_payload": {
    "submodule_name": "$SUBMODULE_NAME",
    "updated_at": "$(date -Iseconds)",
    "triggered_by": "$(git config user.name 2>/dev/null || echo 'Unknown')"
  }
}
EOF
)

# Send the repository dispatch event
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/dispatches"

print_status "Sending repository dispatch event..."

RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$API_URL")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [ "$HTTP_CODE" = "204" ]; then
    print_status "✅ Repository dispatch event sent successfully!"
    print_status "The submodule update workflow should start shortly."
    print_status "Check the Actions tab at: https://github.com/$REPO_OWNER/$REPO_NAME/actions"
else
    print_error "❌ Failed to send repository dispatch event"
    print_error "HTTP Status: $HTTP_CODE"
    if [ -n "$RESPONSE_BODY" ]; then
        print_error "Response: $RESPONSE_BODY"
    fi
    exit 1
fi
