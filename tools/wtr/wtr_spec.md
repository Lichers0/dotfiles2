# wtr — Git Worktree Manager

## Overview

CLI-утилита с TUI-интерфейсом для управления git worktrees. Упрощает создание, переключение и удаление worktrees.

## Features

### Core
- TUI-интерфейс для выбора/создания веток
- Быстрое создание worktree через CLI-аргумент
- Удаление worktrees (без удаления веток)
- **Симлинки для навигации** — `cd wt` из любого worktree → последний активный

### Extended
- **Fuzzy search** — фильтрация веток:
  - Подстрока: `325` → `ENS-325` (score: 100)
  - Подпоследовательность: `ES5` → `ENS-325` (score: 95)
  - Fuzzy matching для опечаток (score: <95)
- **Статус worktree** — индикаторы состояния для каждой ветки:
  - `*` — dirty (незакоммиченные изменения)
  - `[+N]` — количество untracked файлов
  - `↑N ↓M` — ahead/behind remote
  - `Nd` — давность последнего коммита
  - `[S]` — есть stash
  - `[R]`/`[M]` — в процессе rebase/merge
- **Автоочистка** — удаление worktrees для merged/deleted веток (CLI + TUI)
- **Конфиг файл** — `.wtrrc` (TOML) для настроек
- **Shell completions** — автодополнение для zsh/bash/fish
- **Групповые операции** — выбор нескольких worktrees для удаления
- **Превью веток** — последние коммиты при навигации

## Directory Structure

```
<repo_root>/
├── .git/
├── wt -> wtrees/feature-x     # симлинк на последний активный worktree
├── wtrees/                    # директория со всеми worktrees
│   ├── feature-x/
│   │   └── wt -> ../../wt     # симлинк на корневой wt
│   ├── feature-y/
│   │   └── wt -> ../../wt
│   └── ...
└── ...                        # основная ветка (main/master)
```

### Симлинки для навигации

При создании/переключении worktree автоматически:
1. Обновляется `<repo_root>/wt` → последний активный worktree
2. Создаётся `<worktree>/wt` → `../../wt` (ссылка на корневой симлинк)

**Быстрая навигация из любого worktree:**
```bash
cd wt    # → переход в последний активный worktree
```

## Project Structure

```
wtr/
├── pyproject.toml
├── wtr_spec.md
├── shell/
│   ├── wtr.sh                 # shell-обёртка для cd
│   └── completions/
│       ├── wtr.zsh            # zsh completion
│       ├── wtr.bash           # bash completion
│       └── wtr.fish           # fish completion
└── src/wtr/
    ├── __init__.py
    ├── cli.py                 # CLI entry point, argument parsing
    ├── config.py              # Config file loading
    ├── git.py                 # GitWorktreeManager class
    ├── fuzzy.py               # Fuzzy search helpers
    └── tui.py                 # TUI application (textual)
```

## CLI Interface

```bash
wtr                            # launch TUI
wtr <branch>                   # quick create/switch (no TUI)
wtr -l, --list                 # list existing worktrees
wtr -d, --delete <branch>      # delete worktree
wtr -b, --base <branch>        # specify base branch for new worktree
wtr --prune                    # remove worktrees for merged/deleted branches
wtr --completion <shell>       # generate shell completion (zsh/bash/fish)
```

## Exit Codes

| Code | Meaning                              | Shell Action |
|------|--------------------------------------|--------------|
| 0    | Success, stdout contains path       | cd to path   |
| 1    | No action (cancel, list, info)      | print stdout |
| 2    | Error                                | print stderr |

## Shell Integration

`wtr` работает как standalone команда после `pip install`.

**Для auto-cd (опционально):**
```bash
# ~/.zshrc — однострочная функция
wtr() { local p=$(command wtr "$@"); [[ -d "$p" ]] && cd "$p" || echo "$p"; }

# Или source обёртки
source /path/to/wtr/shell/wtr.sh  # создаёт функцию wtrc
```

**Shell completions:**
```bash
eval "$(wtr --completion zsh)"   # zsh
eval "$(wtr --completion bash)"  # bash
```

## TUI Flow

### Main Screen
```
┌──────────────────────────────────────────────────────────┐
│  Git Worktree Manager                                    │
├──────────────────────────────────────────────────────────┤
│  Filter: [feat_______________]                           │
│                                                          │
│  Branches:                                               │
│  ┌────────────────────────────────────────────────────┐  │
│  │ ● main                              ↑1        2h   │  │
│  │   feature-auth    [wt] * [+2]       ↓3        1d   │  │
│  │   feature-api                  [S]            5d   │  │
│  │   feature-db      [wt]                        3d   │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  Preview:                                                │
│  ┌────────────────────────────────────────────────────┐  │
│  │ abc1234 Fix auth flow (2 days ago)                 │  │
│  │ def5678 Add login endpoint (3 days ago)            │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  [Enter] select  [Space] multi  [d] delete  [p] prune    │
│  [q] quit                                                │
└──────────────────────────────────────────────────────────┘
```

### Статус индикаторы
- `●` — текущая ветка
- `[wt]` — есть worktree
- `*` — dirty (есть изменения)
- `[+N]` — untracked файлов
- `↑N ↓M` — ahead/behind remote
- `Nd/Nh` — время последнего коммита
- `[S]` — есть stash
- `[R]` — rebase in progress
- `[M]` — merge in progress

### Dialogs

**Existing worktree:**
```
Worktree: feature-auth
/repo/wtrees/feature-auth
[Go] [Delete] [Cancel]
```

**Create worktree:**
```
Create new branch + worktree
Branch: feature-api
Base branch: [mas___________]
┌────────────────────────────┐
│   master                   │
│   master-backup            │
└────────────────────────────┘
[Create] [Cancel]
```
- Поле ввода с fuzzy-фильтрацией веток
- Выбор базовой ветки из списка или вводом

**After creation:**
```
Go to feature-api?
[Yes] [No]
```

**Prune dialog (in TUI):**
```
Found 3 stale worktrees:
☑ old-feature     (branch deleted)
☑ merged-fix      (merged to main)
☐ wip-experiment  (branch deleted)
[Delete selected] [Cancel]
```

**Multi-delete:**
```
Delete 2 worktrees?
- feature-old
- feature-test
[Delete] [Cancel]
```

## Modules

### git.py — GitWorktreeManager

```python
@dataclass
class BranchStatus:
    dirty: bool                    # uncommitted changes
    untracked_count: int           # untracked files
    ahead: int                     # commits ahead of remote
    behind: int                    # commits behind remote
    last_commit_time: datetime     # last commit timestamp
    has_stash: bool                # has stash entries
    rebase_in_progress: bool       # rebase in progress
    merge_in_progress: bool        # merge in progress

class GitWorktreeManager:
    WORKTREES_DIR = "wtrees"

    def __init__(path: Path | None = None)
    def get_main_branch() -> str
    def list_local_branches() -> list[str]
    def list_worktrees() -> dict[str, Path]
    def branch_exists(name: str) -> bool
    def worktree_exists(branch: str) -> bool
    def get_worktree_path(branch: str) -> Path
    def create_worktree(branch: str, base_branch: str | None = None) -> Path
    def delete_worktree(branch: str) -> None
    def get_current_branch() -> str | None

    # Extended methods
    def get_branch_status(branch: str) -> BranchStatus
    def get_recent_commits(branch: str, count: int = 5) -> list[tuple[str, str, datetime]]
    def find_stale_worktrees() -> list[tuple[str, str]]  # [(branch, reason), ...]
    def is_branch_merged(branch: str, into: str = "main") -> bool
    def prune_worktrees(branches: list[str]) -> None
    def update_symlink(branch: str) -> None  # update wt symlink to point to branch
```

### tui.py — TUI Components

- `WorktreeApp` — main application
- `BranchItem` — list item with status indicators
- `BranchPreview` — commit preview panel
- `ConfirmDialog` — yes/no modal
- `CreateWorktreeDialog` — create worktree modal with fuzzy branch selection
- `WorktreeActionDialog` — go/delete modal
- `PruneDialog` — select stale worktrees modal
- `MultiDeleteDialog` — confirm multi-delete modal

### cli.py — Entry Point

- Argument parsing (argparse)
- Route to TUI or quick commands
- Handle exit codes

### fuzzy.py — Fuzzy Search

```python
def is_subsequence(query: str, text: str) -> bool
    """Check if query chars appear in text in order (e.g. 'ES5' in 'ENS-325')."""

def fuzzy_filter(items: list[str], query: str, threshold: int = 95) -> list[tuple[str, int]]
    """
    Filter items by matching against query. Returns (item, score) sorted by score.
    Scoring:
    - 100: exact substring match
    - 95: subsequence match
    - <95: fuzzy match (thefuzz library)
    """

def fuzzy_match(items: list[str], query: str, threshold: int = 95) -> list[str]
    """Convenience wrapper, returns only item names."""
```

## Config File

`.wtrrc` в корне репозитория или `~/.config/wtr/config.toml`:

```toml
[worktree]
dir = "wtrees"              # worktree directory name
default_base = ""           # empty = auto-detect (main or master)

[ui]
show_status = true          # show status indicators
show_preview = true         # show commit preview
preview_count = 5           # number of commits in preview

[prune]
auto_suggest = true         # suggest prune on TUI start if stale found
```

## Dependencies

```toml
[project]
dependencies = [
    "textual>=0.40.0",
    "GitPython>=3.1.0",
    "thefuzz>=0.22.0",      # fuzzy matching
    "tomli>=2.0.0",         # config parsing (Python < 3.11)
]
```

## Installation

```bash
pip install -e /path/to/wtr
```

**Опционально (auto-cd):**
```bash
# Добавить в ~/.zshrc
wtr() { local p=$(command wtr "$@"); [[ -d "$p" ]] && cd "$p" || echo "$p"; }
eval "$(wtr --completion zsh)"
```
