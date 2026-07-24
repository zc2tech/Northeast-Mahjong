#!/bin/bash
# Script to migrate to a new independent GitHub repository

set -e

echo "=== Migrate to Independent Repository ==="
echo ""
echo "This script will help you create a new independent repository"
echo "with all your changes, detached from the original fork parent."
echo ""

# Get current remote
CURRENT_REMOTE=$(git remote get-url origin)
echo "Current remote: $CURRENT_REMOTE"
echo ""

read -p "Enter your new GitHub repository URL (e.g., git@github.com:yourusername/NewRepoName.git): " NEW_REMOTE

if [ -z "$NEW_REMOTE" ]; then
    echo "Error: No URL provided"
    exit 1
fi

echo ""
echo "Steps that will be performed:"
echo "1. Rename current 'origin' to 'old-origin'"
echo "2. Add new repository as 'origin'"
echo "3. Push all branches and tags to new repository"
echo ""

read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Aborted"
    exit 0
fi

# Rename old origin
git remote rename origin old-origin

# Add new origin
git remote add origin "$NEW_REMOTE"

# Push everything
git push -u origin --all
git push -u origin --tags

echo ""
echo "=== Migration Complete! ==="
echo ""
echo "Your repository is now at: $NEW_REMOTE"
echo "Old remote saved as 'old-origin' (you can remove it with: git remote remove old-origin)"
echo ""
echo "Next steps:"
echo "1. Verify everything at your new GitHub repository"
echo "2. Update any CI/CD settings, webhooks, or integrations"
echo "3. Remove old-origin remote: git remote remove old-origin"
