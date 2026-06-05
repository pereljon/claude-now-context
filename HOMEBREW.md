# Homebrew release process

This project ships via the `pereljon/homebrew-tap` tap. The formula in this repo (`Formula/claude-now-context.rb`) is the source of truth; the deployed copy lives in the tap repo.

## Cutting a release

1. Bump `VERSION` in `claude-now-context`.
2. Bump `version` and update `url` (tag) in `Formula/claude-now-context.rb`.
3. Commit and push to `main`.
4. Tag and push:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
5. Compute the tarball SHA256:
   ```bash
   curl -fsSL https://github.com/pereljon/claude-now-context/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
   ```
6. Update `sha256` in `Formula/claude-now-context.rb`.
7. Copy the formula to the tap repo:
   ```bash
   cp Formula/claude-now-context.rb ../homebrew-tap/Formula/claude-now-context.rb
   cd ../homebrew-tap
   git add Formula/claude-now-context.rb
   git commit -m "claude-now-context 0.1.0"
   git push
   ```

## Verifying the release

```bash
brew untap pereljon/tap 2>/dev/null || true
brew tap pereljon/tap
brew install claude-now-context
claude-now-context --version
claude-now-context --status
```

## Updating between releases

For patch fixes that don't change the user-facing CLI, you can keep the version pinned and update the formula's `url`/`sha256` to point at a new tag. Homebrew users get the fix on `brew upgrade`.
