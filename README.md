# claude-now-context

A tiny [Claude Code](https://docs.claude.com/en/docs/claude-code) hook that injects the current local datetime into every user prompt as context. Claude sees the time on every turn and can reason about "now" without guessing or asking.

## What it does

On every prompt submission, a `UserPromptSubmit` hook runs `date` and emits a one-line context message:

```
Current datetime: 2026-06-05 09:30:00 PDT
```

That line is added to the model's context for the turn. Claude can use it for scheduling, log timestamps, date-aware reasoning, or anything else. It is not forced into the visible response.

## Why

Out of the box, Claude doesn't know the current time. It may infer a stale date from training data, ask the user, or fabricate one. This hook removes the guesswork at negligible token cost (~25 tokens per turn).

## Install

### Homebrew (macOS / Linuxbrew)

```bash
brew tap pereljon/tap
brew install claude-now-context
claude-now-context --install
```

### One-liner (any Unix)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pereljon/claude-now-context/main/install.sh)"
```

Add `project` to scope the install to the current directory's `.claude/settings.json` instead of user-level:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pereljon/claude-now-context/main/install.sh)" -- project
```

### Clone and run

```bash
git clone https://github.com/pereljon/claude-now-context.git
cd claude-now-context
./claude-now-context --install           # user-level
./claude-now-context --install project   # project-level
```

### Manual

Merge the snippet in `hook.json` into your `~/.claude/settings.json` (user-level) or `.claude/settings.json` (project-level). If a `hooks.UserPromptSubmit` array already exists, append the entry rather than overwriting.

Takes effect on your next prompt - `UserPromptSubmit` hooks are re-read from `settings.json` each turn, so no session restart is needed.

## Usage

```bash
claude-now-context --install      # add the hook
claude-now-context --uninstall    # remove it
claude-now-context --status       # report whether installed
claude-now-context --version
claude-now-context --help
```

All commands accept an optional `project` argument to target `.claude/settings.json` in the current directory instead of `~/.claude/settings.json`.

## Requirements

- `jq` (declared as a Homebrew dependency; install manually for the one-liner path)
- `bash`, `date`, `curl`

## Customizing

Change the `date` format string in `claude-now-context` to taste:

| Want | Format |
|------|--------|
| ISO 8601 UTC | `date -u +'%Y-%m-%dT%H:%M:%SZ'` |
| Local with weekday | `date +'%A %Y-%m-%d %H:%M %Z'` |
| Epoch seconds | `date +%s` |
| Human-friendly | `date +'%a %b %e %Y at %l:%M %p %Z'` |

If you customize after installing, uninstall and reinstall so the stored command in `settings.json` matches.

## Making the datetime visible in responses

By default, Claude sees the datetime but doesn't display it. To prefix every response with it, edit the `HOOK_CMD` line in `claude-now-context` to add an instruction:

```bash
HOOK_CMD='echo "Current datetime: $(date +'\''%Y-%m-%d %H:%M:%S %Z'\''). Begin every response with this timestamp on its own line."'
```

This is instruction-based, not enforced. Claude follows it most of the time but may skip it on short replies.

## Uninstall

### Homebrew

```bash
claude-now-context --uninstall
brew uninstall claude-now-context
brew untap pereljon/tap   # optional
```

### One-liner

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pereljon/claude-now-context/main/uninstall.sh)"
```

The uninstall path surgically removes the hook entry, saves a backup, and leaves the rest of your settings untouched. To restore everything to pre-install state instead, recover from the `.bak.*` file created on install.

## How it works

[`UserPromptSubmit`](https://docs.claude.com/en/docs/claude-code/hooks) is a Claude Code hook that fires whenever you submit a prompt, before the model processes it. The hook's stdout becomes additional context for that turn. This project uses one line of shell wrapped in a thin CLI for install/uninstall management.

## Releases

See [HOMEBREW.md](HOMEBREW.md) for the release and tap-update process.

## License

MIT. See [LICENSE](LICENSE).
