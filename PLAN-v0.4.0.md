# v0.4.0 Plan: Response Duration Context

Status: approved, pre-implementation.

## Goal

Inject the duration of Claude's previous response into the next prompt's context. Claude gains awareness of how long it just took to formulate its previous answer.

Example injection on turn 2+:
```
Current datetime: Fri 2026-06-05 15:11:33 PDT. Previous response took 47s.
```

## State file

**Location:** `~/.claude/now-context-state/<session_id>.json`

**Schema:**
```json
{
  "prompt_started": 1738526123,
  "last_duration": 47
}
```

- Both values are integers; `prompt_started` is epoch seconds, `last_duration` is seconds.
- One file per Claude Code session, lazily created.
- Concurrent sessions are naturally isolated by session_id.
- No automatic cleanup in v0.4.0 (files are ~50 bytes; revisit if needed).

## Hook design

`UserPromptSubmit` and `Stop` both invoke the same script with a sub-action.

**UserPromptSubmit hook command:**
```
claude-now-context-hook on-prompt
```

**Stop hook command:**
```
claude-now-context-hook on-stop
```

`claude-now-context-hook` is a new small Perl script installed alongside `claude-now-context`. The main CLI calls it for install/uninstall; the hook itself uses Perl + JSON::PP only.

### `on-prompt` logic
1. Read JSON from stdin → extract `session_id`.
2. Compute `now = time()`.
3. Load state file if it exists.
4. Build emit line:
   - Always include `Current datetime: <formatted now>`.
   - If state exists with `last_duration` set, append `Previous response took <formatted duration>.`
5. Print emit line to stdout.
6. Write fresh state: `{prompt_started: now, last_duration: null}`.

### `on-stop` logic
1. Read JSON from stdin → extract `session_id`.
2. Compute `now = time()`.
3. Load state file (must exist; silently no-op if not).
4. Compute `duration = now - prompt_started`.
5. Write state: `{prompt_started: <unchanged>, last_duration: duration}`. No stdout emitted.

### Duration formatting

| Range | Format | Example |
|---|---|---|
| ≤ 90 sec | `Xs` | "47s" |
| 90s – 1h | `XmYs` | "3m12s" |
| > 1h | `XhYm` | "2h14m" |

## CLI changes

`claude-now-context` CLI gains:

1. **Hook command constants:**
   - `HOOK_CMD_PROMPT` = `<path-to>/claude-now-context-hook on-prompt`
   - `HOOK_CMD_STOP`   = `<path-to>/claude-now-context-hook on-stop`

2. **Signature detection:**
   - `HOOK_SIGNATURE = 'claude-now-context-hook'` (matches both new hooks).
   - `LEGACY_HOOK_SIGNATURE = 'echo "Current datetime:'` (matches v0.1.0 – v0.3.x hooks).
   - Detection matches either; install removes any match before writing the new entries.

3. **install_state** returns `current` only if exactly one `UserPromptSubmit` entry matches `HOOK_CMD_PROMPT` and exactly one `Stop` entry matches `HOOK_CMD_STOP`. Anything else is `outdated` (migrate) or `absent`.

4. **`--install`** writes two hook entries (one in `UserPromptSubmit`, one in `Stop`). Removes legacy/duplicate signature-matching entries first.

5. **`--uninstall`** removes any signature-matching entries from both arrays.

6. **`--status`** reports both hooks individually:
   ```
   prompt hook: installed (path: ~/.claude/settings.json)
   stop hook:   installed
   ```

7. **`--dry-run`** previews both changes.

## Files added/changed

- New: `claude-now-context-hook` (Perl script)
- Modified: `claude-now-context` (multi-hook install/uninstall logic)
- Modified: `Formula/claude-now-context.rb` (installs both scripts to `bin/`)
- Modified: `README.md`
- Modified: `hook.json` (manual-install snippet now includes both hooks)
- Version bumped to 0.4.0

## Migration from v0.3.x

- Existing users have a single `UserPromptSubmit` hook with `echo "Current datetime: ...`.
- On `claude-now-context --install` after upgrade:
  - Detect old signature → classify as `outdated`.
  - Remove old hook.
  - Add new `UserPromptSubmit` + new `Stop` entries pointing at `claude-now-context-hook`.
  - Report: `Upgraded existing datetime hook to the current format and added response-duration tracking in <file>`.

## Edge cases

| Case | Behavior |
|---|---|
| First turn of new session | No state file → emit only datetime, no duration |
| Session resume after restart | New session_id → new state → behaves as first turn |
| Stop hook never fired (crash, force-quit) | State has `prompt_started` but `last_duration` null → next prompt emits datetime only |
| Multiple Stop hooks fire in one turn | Last one wins; `last_duration` overwritten with latest computation |
| Concurrent Claude Code windows | Different session_ids → separate state files → no collision |
| Stale state files from old sessions | Accumulate harmlessly; no GC in v0.4.0 |
| Missing/malformed stdin JSON | Emit datetime only, no duration, no state file changes |
| Missing `session_id` field | Same as above: degrade gracefully |
| State file unreadable / corrupt | Treat as absent: emit datetime only, overwrite with fresh structure |

## Resolved design choices

1. **Hook script location:** `bin/claude-now-context-hook` (alongside the CLI). Simpler than `libexec/` for path discovery.
2. **State directory:** `~/.claude/now-context-state/` (proximate to `settings.json`; no XDG split).
3. **Duration of `0s` or `1s`:** always emit if state is complete. Lets Claude know the data path is working.
4. **Stop firing in tool-using turns:** verify before relying on it. If `Stop` fires multiple times per turn, last write wins and we still capture the true end-of-turn (since on-prompt sets a new `prompt_started`, intra-turn stops do not change start).
5. **macOS `date +%s` resolution:** seconds only. Fast responses (<1s) format as `0s`. Acceptable for v0.4.0; revisit for milliseconds later.

## Testing plan

### Unit-style (sandbox)

For each test: fresh `/tmp/cnc-test/`, fresh fake state dir, then run the hook script directly with hand-crafted JSON on stdin.

1. **First turn (no state file)**
   - Stdin: `{"session_id": "abc"}`. State file absent.
   - Expected: stdout has datetime, no "Previous response" line. State file created with `prompt_started` set, `last_duration` null.

2. **Second turn (full cycle)**
   - Run `on-prompt` with session_id `abc`.
   - Run `on-stop` after sleeping 2s.
   - Run `on-prompt` again after sleeping 1s.
   - Expected on third call: stdout has datetime + "Previous response took 2s" (±1s tolerance).

3. **Stop without prior prompt**
   - Run `on-stop` with no state file. Silent no-op, no error, no file created.

4. **Duration formatting**
   - Force values into state file:
     - `last_duration = 47` → "47s"
     - `last_duration = 95` → "1m35s"
     - `last_duration = 192` → "3m12s"
     - `last_duration = 3700` → "1h1m"
   - Run `on-prompt`; check output formatting.

5. **Missing session_id in JSON**
   - Stdin: `{}`.
   - Expected: stdout has datetime, no duration, no state file created or modified.

6. **Concurrent sessions**
   - Run `on-prompt` for session `aaa`.
   - Run `on-prompt` for session `bbb` (interleaved).
   - Run `on-stop` for `aaa`.
   - Run `on-prompt` for `aaa` → should see duration from aaa's cycle, unaffected by bbb.

7. **State file corruption**
   - Write garbage to state file. Run `on-prompt`. Expected: datetime only, no error, state file overwritten with fresh structure.

### CLI integration (sandbox)

8. **Fresh install adds both hooks.** Verify `UserPromptSubmit` and `Stop` entries present with correct commands.

9. **Migration from v0.3.x.** Seed settings.json with an `echo "Current datetime:` hook. Run `--install`. Expect "Upgraded" message and both new hook entries; old removed.

10. **Idempotent re-install.** Run `--install` twice. Second run: "already installed".

11. **`--status` reports both** prompt and stop hooks installed.

12. **`--uninstall` removes both.** Cleanup of empty `Stop` array verified.

13. **Other hooks preserved.** Settings.json with unrelated `PreToolUse` hook. After install/uninstall round-trip, PreToolUse intact.

14. **`--dry-run` previews both.** Diff shows both new entries would be added; settings.json unchanged.

### Brew end-to-end

15. **`brew upgrade` from v0.3.1.** Existing v0.3.1 install with old-format hook. `brew upgrade && claude-now-context --install`. Expect "Upgraded" message, two new hook entries.

16. **Real session test.** Install in this session. Send a prompt. Verify `Previous response took ...` appears in the *following* `<system-reminder>` (one turn delay is expected).

### Failure-mode tests

17. **Hook script not on PATH.** Manually break the path in settings.json. Claude Code should still function; user sees no datetime injection but no crash.

18. **Perl missing.** Already covered by `require_perl`. CLI errors clearly on `--install`.

19. **Disk full / write failure during state write.** Force-fill the state directory's filesystem. Hook should not crash Claude Code even on write failure.
