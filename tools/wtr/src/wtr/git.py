"""Git operations for worktree management."""

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from git import Repo, InvalidGitRepositoryError
from git.exc import GitCommandError


@dataclass
class BranchStatus:
    """Status information for a branch/worktree."""

    dirty: bool = False
    untracked_count: int = 0
    ahead: int = 0
    behind: int = 0
    last_commit_time: datetime | None = None
    has_stash: bool = False
    rebase_in_progress: bool = False
    merge_in_progress: bool = False


@dataclass
class CommitInfo:
    """Information about a single commit."""

    sha: str
    message: str
    time: datetime


class GitWorktreeManager:
    """Manages git worktrees for a repository."""

    WORKTREES_DIR = "wtrees"

    def __init__(self, path: Path | None = None):
        """Initialize manager from path (defaults to cwd)."""
        self.repo = self._find_repo(path or Path.cwd())
        self.root = Path(self.repo.working_dir)
        self.wtrees_dir = self.root / self.WORKTREES_DIR

    def _find_repo(self, path: Path) -> Repo:
        """Find git repository from path, walking up if needed."""
        try:
            return Repo(path, search_parent_directories=True)
        except InvalidGitRepositoryError:
            raise RuntimeError(f"Not a git repository: {path}")

    def get_main_branch(self) -> str:
        """Determine main branch name (main or master)."""
        branches = [b.name for b in self.repo.branches]
        if "main" in branches:
            return "main"
        if "master" in branches:
            return "master"
        # Fallback to first branch or HEAD
        return branches[0] if branches else "HEAD"

    def list_local_branches(self) -> list[str]:
        """List all local branch names."""
        return sorted([b.name for b in self.repo.branches])

    def list_worktrees(self) -> dict[str, Path]:
        """Return dict of {branch_name: worktree_path} for existing worktrees."""
        worktrees = {}
        if not self.wtrees_dir.exists():
            return worktrees

        for item in self.wtrees_dir.iterdir():
            if item.is_dir() and (item / ".git").exists():
                # Get branch name from worktree
                try:
                    wt_repo = Repo(item)
                    if not wt_repo.head.is_detached:
                        branch_name = wt_repo.active_branch.name
                        worktrees[branch_name] = item
                except Exception:
                    # Directory exists but not a valid worktree
                    pass
        return worktrees

    def branch_exists(self, name: str) -> bool:
        """Check if local branch exists."""
        return name in self.list_local_branches()

    def worktree_exists(self, branch: str) -> bool:
        """Check if worktree for branch exists."""
        return branch in self.list_worktrees()

    def get_worktree_path(self, branch: str) -> Path:
        """Get path where worktree for branch would be located."""
        return self.wtrees_dir / branch

    def create_worktree(self, branch: str, base_branch: str | None = None) -> Path:
        """
        Create worktree for branch.

        If branch doesn't exist, creates it from base_branch.
        Returns path to created worktree.
        """
        worktree_path = self.get_worktree_path(branch)

        # Ensure wtrees directory exists
        self.wtrees_dir.mkdir(exist_ok=True)

        if worktree_path.exists():
            raise RuntimeError(f"Directory already exists: {worktree_path}")

        try:
            if self.branch_exists(branch):
                # Branch exists, just create worktree
                self.repo.git.worktree("add", str(worktree_path), branch)
            else:
                # Create new branch from base
                base = base_branch or self.get_main_branch()
                self.repo.git.worktree("add", "-b", branch, str(worktree_path), base)
        except GitCommandError as e:
            raise RuntimeError(f"Failed to create worktree: {e}")

        # Create symlink inside worktree pointing to root's wt symlink
        inner_symlink = worktree_path / "wt"
        if not inner_symlink.exists():
            inner_symlink.symlink_to("../../wt")

        return worktree_path

    def delete_worktree(self, branch: str) -> None:
        """Delete worktree for branch (keeps the branch itself)."""
        worktrees = self.list_worktrees()

        if branch not in worktrees:
            raise RuntimeError(f"No worktree for branch: {branch}")

        worktree_path = worktrees[branch]

        try:
            # Remove from git
            self.repo.git.worktree("remove", str(worktree_path), "--force")
        except GitCommandError as e:
            raise RuntimeError(f"Failed to delete worktree: {e}")

    def get_current_branch(self) -> str | None:
        """Get current branch name or None if detached."""
        if self.repo.head.is_detached:
            return None
        return self.repo.active_branch.name

    def update_symlink(self, branch: str) -> None:
        """Update 'wt' symlink in repo root to point to worktree."""
        worktrees = self.list_worktrees()
        if branch not in worktrees:
            return

        symlink_path = self.root / "wt"
        target = worktrees[branch]

        # Remove existing symlink
        if symlink_path.is_symlink():
            symlink_path.unlink()
        elif symlink_path.exists():
            return  # Don't overwrite non-symlink

        # Create relative symlink
        try:
            rel_target = target.relative_to(self.root)
            symlink_path.symlink_to(rel_target)
        except ValueError:
            # Fallback to absolute if relative fails
            symlink_path.symlink_to(target)

    def get_branch_status(self, branch: str) -> BranchStatus:
        """Get detailed status for a branch."""
        status = BranchStatus()

        # Find the repo to check - either worktree or main repo
        worktrees = self.list_worktrees()
        if branch in worktrees:
            try:
                repo = Repo(worktrees[branch])
            except Exception:
                return status
        elif branch == self.get_current_branch():
            repo = self.repo
        else:
            # Branch exists but no worktree - get last commit time only
            try:
                branch_ref = self.repo.heads[branch]
                status.last_commit_time = datetime.fromtimestamp(
                    branch_ref.commit.committed_date
                )
            except Exception:
                pass
            return status

        # Check dirty status
        status.dirty = repo.is_dirty(untracked_files=False)

        # Count untracked files
        status.untracked_count = len(repo.untracked_files)

        # Check ahead/behind
        try:
            branch_ref = repo.active_branch
            tracking = branch_ref.tracking_branch()
            if tracking:
                ahead = len(list(repo.iter_commits(f"{tracking}..{branch_ref}")))
                behind = len(list(repo.iter_commits(f"{branch_ref}..{tracking}")))
                status.ahead = ahead
                status.behind = behind
        except Exception:
            pass

        # Last commit time
        try:
            status.last_commit_time = datetime.fromtimestamp(
                repo.head.commit.committed_date
            )
        except Exception:
            pass

        # Check for stash
        try:
            stash_list = repo.git.stash("list")
            status.has_stash = bool(stash_list.strip())
        except Exception:
            pass

        # Check rebase in progress
        git_dir = Path(repo.git_dir)
        status.rebase_in_progress = (
            (git_dir / "rebase-merge").exists()
            or (git_dir / "rebase-apply").exists()
        )

        # Check merge in progress
        status.merge_in_progress = (git_dir / "MERGE_HEAD").exists()

        return status

    def get_recent_commits(self, branch: str, count: int = 5) -> list[CommitInfo]:
        """Get recent commits for a branch."""
        commits = []
        try:
            branch_ref = self.repo.heads[branch]
            for commit in list(branch_ref.commit.iter_parents())[:count]:
                commits.append(
                    CommitInfo(
                        sha=commit.hexsha[:7],
                        message=commit.message.split("\n")[0][:60],
                        time=datetime.fromtimestamp(commit.committed_date),
                    )
                )
            # Include the branch tip commit itself
            tip = branch_ref.commit
            commits.insert(
                0,
                CommitInfo(
                    sha=tip.hexsha[:7],
                    message=tip.message.split("\n")[0][:60],
                    time=datetime.fromtimestamp(tip.committed_date),
                ),
            )
            commits = commits[:count]
        except Exception:
            pass
        return commits

    def is_branch_merged(self, branch: str, into: str | None = None) -> bool:
        """Check if branch is merged into target branch."""
        target = into or self.get_main_branch()
        try:
            # Check if branch commit is ancestor of target
            branch_commit = self.repo.heads[branch].commit
            target_commit = self.repo.heads[target].commit
            return self.repo.is_ancestor(branch_commit, target_commit)
        except Exception:
            return False

    def find_stale_worktrees(self) -> list[tuple[str, str]]:
        """
        Find worktrees that can be pruned.

        Returns list of (branch_name, reason) tuples.
        Reasons: "branch deleted", "merged to main"
        """
        stale = []
        worktrees = self.list_worktrees()
        local_branches = set(self.list_local_branches())
        main_branch = self.get_main_branch()

        for branch in worktrees:
            # Check if branch was deleted
            if branch not in local_branches:
                stale.append((branch, "branch deleted"))
                continue

            # Check if merged to main (skip main itself)
            if branch != main_branch and self.is_branch_merged(branch, main_branch):
                stale.append((branch, f"merged to {main_branch}"))

        return stale

    def prune_worktrees(self, branches: list[str]) -> dict[str, str | None]:
        """
        Delete multiple worktrees.

        Returns dict of {branch: error_message or None}.
        """
        results = {}
        for branch in branches:
            try:
                self.delete_worktree(branch)
                results[branch] = None
            except RuntimeError as e:
                results[branch] = str(e)
        return results
