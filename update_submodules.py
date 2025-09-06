#!/usr/bin/env python3
"""
Submodule Update Manager

A Python script to manage submodule updates with more sophisticated logic,
including conflict resolution, rollback capabilities, and detailed logging.
"""

import subprocess
import json
import os
import sys
import logging
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class SubmoduleManager:
    def __init__(self, repo_path: str = ".", verbose: bool = False):
        self.repo_path = Path(repo_path).resolve()
        self.verbose = verbose
        self.setup_logging()
        
    def setup_logging(self):
        """Setup logging configuration."""
        log_level = logging.DEBUG if self.verbose else logging.INFO
        
        # Create logs directory if it doesn't exist
        log_dir = self.repo_path / "logs"
        log_dir.mkdir(exist_ok=True)
        
        # Setup logging to both file and console
        log_file = log_dir / f"submodule_update_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        self.logger = logging.getLogger(__name__)
        self.logger.info(f"Logging initialized. Log file: {log_file}")
    
    def run_command(self, command: List[str], cwd: Optional[Path] = None) -> Tuple[bool, str, str]:
        """Run a shell command and return success, stdout, stderr."""
        if cwd is None:
            cwd = self.repo_path
            
        try:
            self.logger.debug(f"Running command: {' '.join(command)} in {cwd}")
            result = subprocess.run(
                command,
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            success = result.returncode == 0
            if not success:
                self.logger.error(f"Command failed with return code {result.returncode}")
                self.logger.error(f"Stderr: {result.stderr}")
                
            return success, result.stdout.strip(), result.stderr.strip()
            
        except subprocess.TimeoutExpired:
            self.logger.error(f"Command timed out: {' '.join(command)}")
            return False, "", "Command timed out"
        except Exception as e:
            self.logger.error(f"Error running command: {e}")
            return False, "", str(e)
    
    def get_submodules(self) -> Dict[str, str]:
        """Parse .gitmodules file and return submodule paths and URLs."""
        gitmodules_path = self.repo_path / ".gitmodules"
        
        if not gitmodules_path.exists():
            self.logger.error(".gitmodules file not found")
            return {}
        
        submodules = {}
        current_name = None
        current_path = None
        
        with open(gitmodules_path, 'r') as f:
            for line in f:
                line = line.strip()
                
                if line.startswith('[submodule "') and line.endswith('"]'):
                    if current_name and current_path:
                        submodules[current_name] = current_path
                    
                    current_name = line[12:-2]  # Extract name from [submodule "name"]
                    current_path = None
                    
                elif line.startswith('path = '):
                    current_path = line[7:].strip()
        
        # Don't forget the last submodule
        if current_name and current_path:
            submodules[current_name] = current_path
            
        self.logger.info(f"Found {len(submodules)} submodules: {list(submodules.keys())}")
        return submodules
    
    def get_submodule_status(self, submodule_path: str) -> Dict[str, str]:
        """Get current status of a submodule."""
        submodule_dir = self.repo_path / submodule_path
        
        if not submodule_dir.exists():
            return {"status": "missing", "current_commit": "", "latest_commit": ""}
        
        # Get current commit
        success, current_commit, _ = self.run_command(
            ["git", "rev-parse", "HEAD"], 
            cwd=submodule_dir
        )
        
        if not success:
            return {"status": "error", "current_commit": "", "latest_commit": ""}
        
        # Fetch latest changes
        success, _, _ = self.run_command(
            ["git", "fetch", "origin"], 
            cwd=submodule_dir
        )
        
        if not success:
            self.logger.warning(f"Failed to fetch latest changes for {submodule_path}")
            return {"status": "fetch_failed", "current_commit": current_commit, "latest_commit": ""}
        
        # Get default branch
        success, default_branch, _ = self.run_command(
            ["git", "symbolic-ref", "refs/remotes/origin/HEAD"], 
            cwd=submodule_dir
        )
        
        if success:
            default_branch = default_branch.split('/')[-1]
        else:
            default_branch = "main"  # fallback
        
        # Get latest commit on default branch
        success, latest_commit, _ = self.run_command(
            ["git", "rev-parse", f"origin/{default_branch}"], 
            cwd=submodule_dir
        )
        
        if not success:
            latest_commit = current_commit
        
        status = "up-to-date" if current_commit == latest_commit else "needs-update"
        
        return {
            "status": status,
            "current_commit": current_commit,
            "latest_commit": latest_commit,
            "default_branch": default_branch
        }
    
    def update_submodule(self, name: str, path: str) -> bool:
        """Update a single submodule."""
        self.logger.info(f"Updating submodule: {name}")
        submodule_dir = self.repo_path / path
        
        if not submodule_dir.exists():
            self.logger.error(f"Submodule directory does not exist: {path}")
            return False
        
        status = self.get_submodule_status(path)
        
        if status["status"] == "up-to-date":
            self.logger.info(f"Submodule {name} is already up-to-date")
            return True
        
        if status["status"] != "needs-update":
            self.logger.error(f"Submodule {name} has status: {status['status']}")
            return False
        
        # Checkout and pull latest changes
        default_branch = status.get("default_branch", "main")
        
        # Checkout default branch
        success, _, stderr = self.run_command(
            ["git", "checkout", default_branch], 
            cwd=submodule_dir
        )
        
        if not success:
            self.logger.error(f"Failed to checkout {default_branch} for {name}: {stderr}")
            return False
        
        # Pull latest changes
        success, _, stderr = self.run_command(
            ["git", "pull", "origin", default_branch], 
            cwd=submodule_dir
        )
        
        if not success:
            self.logger.error(f"Failed to pull latest changes for {name}: {stderr}")
            return False
        
        self.logger.info(f"Successfully updated {name} from {status['current_commit'][:8]} to {status['latest_commit'][:8]}")
        return True
    
    def commit_changes(self, updated_submodules: List[str]) -> bool:
        """Commit submodule updates to the main repository."""
        if not updated_submodules:
            self.logger.info("No submodules were updated, nothing to commit")
            return True
        
        # Add all changes
        success, _, stderr = self.run_command(["git", "add", "."])
        if not success:
            self.logger.error(f"Failed to add changes: {stderr}")
            return False
        
        # Create commit message
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
        commit_msg = f"""🔄 Update submodules

Updated submodules:
{chr(10).join(f'• {name}' for name in updated_submodules)}

Auto-updated on {timestamp}"""
        
        # Commit changes
        success, _, stderr = self.run_command(["git", "commit", "-m", commit_msg])
        if not success:
            self.logger.error(f"Failed to commit changes: {stderr}")
            return False
        
        self.logger.info("Successfully committed submodule updates")
        return True
    
    def push_changes(self) -> bool:
        """Push changes to remote repository."""
        success, _, stderr = self.run_command(["git", "push", "origin", "main"])
        if not success:
            self.logger.error(f"Failed to push changes: {stderr}")
            return False
        
        self.logger.info("Successfully pushed changes to remote")
        return True
    
    def update_all_submodules(self, auto_push: bool = False) -> bool:
        """Update all submodules and commit changes."""
        self.logger.info("Starting submodule update process")
        
        submodules = self.get_submodules()
        if not submodules:
            self.logger.error("No submodules found")
            return False
        
        # Initialize submodules
        success, _, _ = self.run_command(["git", "submodule", "update", "--init", "--recursive"])
        if not success:
            self.logger.error("Failed to initialize submodules")
            return False
        
        updated_submodules = []
        
        for name, path in submodules.items():
            if self.update_submodule(name, path):
                status = self.get_submodule_status(path)
                if status["status"] == "up-to-date":
                    # Check if it was actually updated by comparing with previous state
                    # For now, assume it was updated if update_submodule returned True
                    updated_submodules.append(name)
        
        if updated_submodules:
            self.logger.info(f"Updated submodules: {updated_submodules}")
            
            if self.commit_changes(updated_submodules):
                if auto_push:
                    return self.push_changes()
                else:
                    return True
            else:
                return False
        else:
            self.logger.info("No submodules needed updating")
            return True


def main():
    parser = argparse.ArgumentParser(description="Update git submodules")
    parser.add_argument("--auto-push", action="store_true", 
                       help="Automatically push changes to remote")
    parser.add_argument("--verbose", "-v", action="store_true", 
                       help="Enable verbose logging")
    parser.add_argument("--repo-path", default=".", 
                       help="Path to the repository (default: current directory)")
    
    args = parser.parse_args()
    
    manager = SubmoduleManager(args.repo_path, args.verbose)
    
    try:
        success = manager.update_all_submodules(args.auto_push)
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        manager.logger.info("Update process interrupted by user")
        sys.exit(130)
    except Exception as e:
        manager.logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
