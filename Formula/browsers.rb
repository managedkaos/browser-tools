class Browsers < Formula
  desc "Tools for working with web browsers on macOS"
  homepage "https://github.com/managedkaos/browser-tools"
  url "https://github.com/managedkaos/browser-tools/releases/download/v0.1.0/browsers-0.1.0-macos-universal.tar.gz"
  sha256 "REPLACE_WITH_SHA256_FROM_make_release"
  license "MIT"

  depends_on macos: :sonoma

  def install
    bin.install "browsers"
    generate_completions_from_executable(bin/"browsers", "--generate-completion-script")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/browsers --version")
    assert_match "name", shell_output("#{bin}/browsers list --json")
  end
end
