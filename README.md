# vc — Simple Version Control Helper

A minimal git wrapper that brings **save / rollback** workflow to any project with a single command.

## Install into any project

```bash
curl -fsSL https://raw.githubusercontent.com/realpkuasule/vc/main/install.sh | bash
./vc init
```

That's it. Two files are added to your project:
```
your-project/
├── vc                  # shortcut (commit this)
└── scripts/
    └── vc.sh           # main script (commit this)
```

## Commands

| Command | Description |
|---------|-------------|
| `./vc init` | Init git repo + `.gitignore` + first commit |
| `./vc save "message"` | Commit everything and tag the snapshot |
| `./vc list` | List all saved snapshots |
| `./vc show <tag>` | Show details of a snapshot |
| `./vc rollback <tag>` | Reset to a snapshot (auto backup branch) |
| `./vc diff <tag1> <tag2>` | Compare two snapshots |
| `./vc log` | Recent commit graph |
| `./vc status` | Working tree status |
| `./vc backup` | Export HEAD to `backup/<timestamp>.tar.gz` |

## Typical workflow

```bash
# Start
./vc init

# Work, then save a snapshot
./vc save "add streaming support"

# See all snapshots
./vc list

# Something broke? Roll back
./vc rollback v20260311-085545

# Compare versions
./vc diff v20260310-150000 v20260311-085545
```

## Rollback is safe

Before resetting, `rollback` automatically creates a backup branch so you can always undo the undo:

```
⚠  This will discard all uncommitted changes.
   Target: v20260310-150000
Confirm? (yes/no): yes
  Current state saved to branch: backup-20260311-090123
✓ Rolled back to v20260310-150000
  To undo: git checkout backup-20260311-090123
```

## Requirements

- `bash`
- `git`
- `curl` (only for the one-line installer)

Works on macOS, Linux, and WSL.
