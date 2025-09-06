# 🔄 Submodule Update System

This repository includes an automated system to keep submodules synchronized with their remote repositories. The system provides multiple ways to trigger and manage submodule updates.

## 📁 Files Overview

- **`update-submodules.sh`** - Main bash script for updating submodules
- **`update_submodules.py`** - Advanced Python script with detailed logging and error handling
- **`webhook-trigger.sh`** - Script to trigger updates via GitHub API
- **`.github/workflows/update-submodules.yml`** - GitHub Actions workflow for automated updates

## 🚀 Quick Start

### Option 1: Manual Update (Bash)

```bash
# Make the script executable
chmod +x update-submodules.sh

# Run the update (will ask before pushing)
./update-submodules.sh

# Run with auto-push (for CI/CD)
./update-submodules.sh --auto-push
```

### Option 2: Manual Update (Python)

```bash
# Basic update
python3 update_submodules.py

# With auto-push and verbose logging
python3 update_submodules.py --auto-push --verbose

# Specify custom repository path
python3 update_submodules.py --repo-path /path/to/repo
```

### Option 3: Trigger from Individual Submodules

Set up webhooks in your individual repositories to trigger updates:

```bash
# Set your GitHub token
export GITHUB_TOKEN=your_personal_access_token_here

# Trigger update for a specific submodule
./webhook-trigger.sh telegram-download-manager

# Or specify all parameters manually
./webhook-trigger.sh parsec ADPer0705 vibe-coding
```

## 🤖 Automated Updates

### GitHub Actions Workflow

The system automatically checks for updates every 6 hours using GitHub Actions. The workflow:

1. **Scheduled runs**: Every 6 hours via cron job
2. **Manual trigger**: Can be triggered manually from the Actions tab
3. **Webhook trigger**: Can be triggered by individual submodule repositories

### Setting Up Individual Repository Webhooks

To trigger updates from your individual repositories, add this to their GitHub Actions:

```yaml
# In your submodule repository: .github/workflows/trigger-parent-update.yml
name: Trigger Parent Repository Update

on:
  push:
    branches: [ main ]

jobs:
  trigger-update:
    runs-on: ubuntu-latest
    steps:
    - name: Trigger parent repository update
      run: |
        curl -X POST \
          -H "Accept: application/vnd.github.v3+json" \
          -H "Authorization: token ${{ secrets.PARENT_REPO_TOKEN }}" \
          -H "Content-Type: application/json" \
          -d '{"event_type":"submodule-updated","client_payload":{"submodule_name":"${{ github.event.repository.name }}"}}' \
          https://api.github.com/repos/ADPer0705/vibe-coding/dispatches
```

**Note**: You'll need to create a `PARENT_REPO_TOKEN` secret in each submodule repository with a GitHub token that has access to trigger workflows in this repository.

## 🔧 Configuration

### Environment Variables

- **`GITHUB_TOKEN`**: Required for webhook triggers
- **`REPO_OWNER`**: Repository owner (auto-detected if not set)
- **`REPO_NAME`**: Repository name (auto-detected if not set)

### Customizing Update Frequency

Edit `.github/workflows/update-submodules.yml` to change the schedule:

```yaml
schedule:
  # Every hour
  - cron: '0 * * * *'
  
  # Every day at 2 AM UTC
  - cron: '0 2 * * *'
  
  # Every Monday at 9 AM UTC
  - cron: '0 9 * * 1'
```

## 📊 Monitoring

### Logs

The Python script creates detailed logs in the `logs/` directory:

```bash
# View recent logs
ls -la logs/
tail -f logs/submodule_update_*.log
```

### GitHub Actions

Monitor automated updates in the GitHub Actions tab:
- View workflow runs and their status
- Check the job summary for update details
- Review any error messages or failures

## 🔒 Security Considerations

1. **Token Permissions**: Ensure GitHub tokens have minimal required permissions:
   - `repo` scope for accessing repository
   - `workflow` scope for triggering actions

2. **Secret Management**: Store tokens as GitHub Secrets, never in code

3. **Branch Protection**: Consider using branch protection rules if this system will auto-push to protected branches

## 🐛 Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure scripts are executable (`chmod +x script.sh`)

2. **Git Authentication**: Ensure proper SSH keys or token authentication is set up

3. **Submodule Not Found**: Run `git submodule update --init --recursive` first

4. **Webhook Failures**: Check that:
   - GitHub token has correct permissions
   - Repository owner/name are correct
   - Network connectivity is available

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Bash script with set -x for debug output
bash -x update-submodules.sh

# Python script with verbose flag
python3 update_submodules.py --verbose
```

## 🎯 Integration with Development Workflow

### For Individual Projects

When working on individual projects, you can trigger updates immediately:

```bash
# After pushing changes to a submodule
cd /path/to/your/submodule
git push origin main

# Then trigger the parent repository update
cd /path/to/vibe-coding
export GITHUB_TOKEN=your_token
./webhook-trigger.sh your-submodule-name
```

### For Continuous Integration

The system is designed to work well with CI/CD pipelines:

1. Submodules are updated automatically
2. Changes are committed with descriptive messages
3. Updates include timestamps and submodule lists
4. Failures are logged and reported

## 📈 Extending the System

### Adding New Submodules

1. Add the submodule to the repository:
   ```bash
   git submodule add https://github.com/user/repo.git path/to/submodule
   ```

2. The system will automatically detect and manage the new submodule

### Custom Update Logic

Modify the scripts to add custom logic:

- Pre/post-update hooks
- Conditional updates based on branch or tags
- Integration with issue tracking
- Custom notification systems

---

## 💡 Tips

- **Regular Monitoring**: Check the Actions tab regularly for any failed updates
- **Local Testing**: Test updates locally before relying on automation
- **Backup Strategy**: Consider having a backup/rollback plan for critical updates
- **Documentation**: Keep your submodule dependencies documented

---

*Part of the Vibe Coding Collection - where functionality meets automation! 🌊*
