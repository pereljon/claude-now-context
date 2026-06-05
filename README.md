# claude-now-context

A tiny [Claude Code](https://docs.claude.com/en/docs/claude-code) hook that injects the current local datetime into every user prompt as context. Claude sees the time on every turn and can reason about "now" without guessing or asking.

## What it does

On every prompt submission, a `UserPromptSubmit` hook runs `date` and emits a one-line context message:

```
Current datetime: Fri 2026-06-05 09:30:00 PDT
```

That line is added to the model's context for the turn. Claude can use it for scheduling, log timestamps, date-aware reasoning, or anything else. It is not forced into the visible response.

## Cost

**~25 tokens per turn. No tool use.** The injected line ("Current datetime: Fri 2026-06-05 09:30:00 PDT") tokenizes to ~15 tokens; Claude Code wraps hook stdout in a `<system-reminder>` block adding another ~10. Over a 100-turn conversation that's ~2,500 tokens, well under 0.05% of a 200K context window. Because the datetime arrives as injected context, Claude never has to call a tool (Bash, MCP, etc.) to get it - no permission prompts, no tool-call latency, no extra tokens beyond the injected line.

## Why

Out of the box, Claude doesn't know the current time. It may infer a stale date from training data, ask the user, or fabricate one. This hook removes the guesswork at negligible token cost.

## Why a hook (and not something else)

A `UserPromptSubmit` hook is the only mechanism that (a) fires on every turn so the datetime never goes stale, (b) injects directly into context with no tool call, and (c) requires zero awareness from Claude. Every alternative either goes stale, costs a tool call, or relies on Claude remembering to fetch the time.

| Approach | How it works | Why it's worse |
|---|---|---|
| **`UserPromptSubmit` hook** *(this project)* | Fires every turn; injects a fresh datetime into the prompt context | — |
| `SessionStart` hook | Injects datetime once when the session opens | Goes stale within minutes; long sessions end up with a wrong "now" |
| `CLAUDE.md` instruction | Tells Claude to run `date` at the start of every reply | Costs a Bash tool call per turn (permission prompt, latency, more tokens). Compliance is unreliable. Verified not to work in practice |
| MCP server exposing `get_datetime` | Claude calls a tool on demand | Claude has to know to call it; setup overhead; tool call latency |
| Custom system prompt | Embed datetime in the session's system prompt | Static for the session; same staleness problem as `SessionStart` |
| Status line script | Show datetime in the Claude Code UI bar | Display only; the model never sees it in context |
| Scheduled task writing to a file | Cron writes `now.txt`, Claude reads it when needed | Claude has to know to read it; tool call cost; still leaves staleness between reads |

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

No external dependencies beyond what ships with the OS. The CLI uses Perl with the `JSON::PP` core module for safe JSON edits, both of which are present on macOS and standard Linux distributions out of the box.

- `bash`, `date`, `perl` (with `JSON::PP`)
- `curl` for the one-liner install

## Customizing

Change the `date` format string in `claude-now-context` to taste:

| Want | Format |
|------|--------|
| ISO 8601 UTC | `date -u +'%Y-%m-%dT%H:%M:%SZ'` |
| Local with weekday | `date +'%A %Y-%m-%d %H:%M %Z'` |
| Epoch seconds | `date +%s` |
| Human-friendly | `date +'%a %b %e %Y at %l:%M %p %Z'` |

If you customize after installing, uninstall and reinstall so the stored command in `settings.json` matches.

> Note for clone-and-customize users: `brew upgrade` overwrites the script with the project default. If you've edited `HOOK_CMD` locally and later switch to Homebrew, your custom format will be replaced on the next upgrade. Install from a clone (`./claude-now-context --install`) if you want to keep customizations across upgrades.

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
