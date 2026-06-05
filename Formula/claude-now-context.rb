# Homebrew formula for claude-now-context.
#
# This file is the source-of-truth copy. The deployed copy lives in the
# pereljon/homebrew-tap repository at:
#   Formula/claude-now-context.rb
#
# To publish a new release, see HOMEBREW.md.

class ClaudeNowContext < Formula
  desc "Claude Code hook that injects current datetime and response duration into every prompt"
  homepage "https://github.com/pereljon/claude-now-context"
  url "https://github.com/pereljon/claude-now-context/archive/refs/tags/v0.4.1.tar.gz"
  sha256 "8398a8dad82842ba6d00524d8b7f780a767814e01eb6f183e8f4f723bdd8e05e"
  license "MIT"
  version "0.4.1"

  # No runtime dependencies: uses Perl + JSON::PP, which ship with macOS and
  # standard Linux distributions.

  def install
    bin.install "claude-now-context"
    bin.install "claude-now-context-hook"
  end

  test do
    assert_match "claude-now-context", shell_output("#{bin}/claude-now-context --version")
    assert_match "USAGE", shell_output("#{bin}/claude-now-context --help")
    assert_match "Current datetime:", shell_output("echo '{}' | #{bin}/claude-now-context-hook on-prompt")
  end
end
