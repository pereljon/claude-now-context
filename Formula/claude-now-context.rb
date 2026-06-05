# Homebrew formula for claude-now-context.
#
# This file is the source-of-truth copy. The deployed copy lives in the
# pereljon/homebrew-tap repository at:
#   Formula/claude-now-context.rb
#
# To publish a new release, see HOMEBREW.md.

class ClaudeNowContext < Formula
  desc "Claude Code hook that injects current datetime into every prompt as context"
  homepage "https://github.com/pereljon/claude-now-context"
  url "https://github.com/pereljon/claude-now-context/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "62bfa9089588de32bd52c54501e4355db4185728d3bee95e1ac895bea6c4f574"
  license "MIT"
  version "0.1.0"

  depends_on "jq"

  def install
    bin.install "claude-now-context"
  end

  test do
    assert_match "claude-now-context", shell_output("#{bin}/claude-now-context --version")
    assert_match "USAGE", shell_output("#{bin}/claude-now-context --help")
  end
end
