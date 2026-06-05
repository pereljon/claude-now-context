# claude-now-context

A tiny [Claude Code](https://docs.claude.com/en/docs/claude-code) hook that injects the current local datetime and previous-response duration into every user prompt as context. Claude sees the time and knows how long its last response took, without guessing or asking.

## What it does

On every prompt submission, a `UserPromptSubmit` hook emits a one-line context message:

```
Current datetime: Fri 2026-06-05 09:30:00 PDT
```

On the second turn and beyond, the duration of Claude's previous response is also included:

```
Current datetime: Fri 2026-06-05 09:31:47 PDT. Previous response took 47s.
```

A matching `Stop` hook measures how long each response took and stores it for the next turn.

That line is added to the model's context for the turn. Claude can use it for scheduling, log timestamps, date-aware reasoning, or estimating how complex its last answer was. It is not forced into the visible response.

## Cost

**~35 tokens per turn. No tool use.** The injected line tokenizes to roughly 20-25 tokens; Claude Code wraps hook stdout in a `<system-reminder>` block adding another ~10. The first turn (datetime only) is closer to 25 tokens. Over a 100-turn conversation that is ~3,500 tokens, well under 0.05% of a 200K context window. Because datetime and duration arrive as injected context, Claude never has to call a tool to get them: no permission prompts, no tool-call latency, no extra tokens beyond the injected line.

## Why

Out of the box, Claude doesn't know the current time or how long it just spent on a response. It may infer a stale date from training data, ask the user, or fabricate one. This hook removes the guesswork at negligible token cost.

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

Merge the snippet in `hook.json` into your `~/.claude/settings.json` (user-level) or `.claude/settings.json` (project-level). Replace `/path/to/claude-now-context-hook` with the actual path to the installed script (run `which claude-now-context-hook` after a Homebrew install). Both the `UserPromptSubmit` and `Stop` entries are required.

Takes effect on your next prompt - hooks are re-read from `settings.json` each turn, so no session restart is needed.

## Usage

```bash
claude-now-context --install      # add both hooks
claude-now-context --uninstall    # remove them
claude-now-context --status       # report whether installed
claude-now-context --version
claude-now-context --help
```

All commands accept an optional `project` argument to target `.claude/settings.json` in the current directory instead of `~/.claude/settings.json`.

## Upgrading from v0.3.x

Run `--install` after `brew upgrade` (or after pulling the latest clone). The CLI detects the old-format hook automatically and replaces it with the new two-hook setup:

```
Upgraded existing datetime hook to the current format and added response-duration tracking in ~/.claude/settings.json
```

No manual cleanup needed.

## Requirements

No external dependencies beyond what ships with the OS. The CLI uses Perl with the `JSON::PP` core module for safe JSON edits, both of which are present on macOS and standard Linux distributions out of the box.

- `bash`, `date`, `perl` (with `JSON::PP`)
- `curl` for the one-liner install

## How it works

[`UserPromptSubmit`](https://docs.claude.com/en/docs/claude-code/hooks) is a Claude Code hook that fires whenever you submit a prompt, before the model processes it. The hook's stdout becomes additional context for that turn.

[`Stop`](https://docs.claude.com/en/docs/claude-code/hooks) fires when Claude finishes a response. This project uses a `Stop` hook to record when the response ended into a per-session state file (`~/.claude/now-context-state/<session_id>.json`). The next `UserPromptSubmit` reads that file, computes the duration, and includes it in the injected line.

Both hooks are managed by a single Perl script (`claude-now-context-hook`) installed alongside the main CLI. Concurrent Claude Code sessions are naturally isolated by their session IDs.

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

The uninstall path surgically removes both hook entries, saves a backup, and leaves the rest of your settings untouched. It also removes the session state directory (`~/.claude/now-context-state/`) and all state files.

## Making the datetime visible in responses

By default, Claude sees the datetime but doesn't display it. To prefix every response with it, add an instruction to your `CLAUDE.md`:

```markdown
Begin every response with the current datetime from context.
```

This is instruction-based, not enforced. Claude follows it most of the time but may skip it on short replies.

## Releases

See [HOMEBREW.md](HOMEBREW.md) for the release and tap-update process.

## License

MIT. See [LICENSE](LICENSE).
