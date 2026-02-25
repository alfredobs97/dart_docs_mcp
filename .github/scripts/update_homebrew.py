#!/usr/bin/env python3
"""
Updates the dart-docs-mcp Homebrew formula with the new version,
download URLs, and SHA256 checksums.

Usage:
  python3 update_homebrew.py <formula_path> <tag> <sha256_macos> <sha256_linux>

Example:
  python3 update_homebrew.py Formula/dart-docs-mcp.rb 0.0.2 abc123... def456...
"""

import re
import sys


def update_formula(formula_path: str, tag: str, sha_macos: str, sha_linux: str) -> None:
    version = tag.lstrip("v")
    base_url = "https://github.com/alfredobs97/dart_docs_mcp/releases/download"

    with open(formula_path) as f:
        content = f.read()

    # Update version field
    content = re.sub(r'version "[^"]*"', f'version "{version}"', content)

    # Update macOS URL
    content = re.sub(
        rf'url "{re.escape(base_url)}/[^"]*dart-docs-mcp-macos\.tar\.gz"',
        f'url "{base_url}/{tag}/dart-docs-mcp-macos.tar.gz"',
        content,
    )

    # Update macOS sha256 (inside the `if OS.mac?` block)
    content = re.sub(
        r'(if OS\.mac\?.*?sha256 ")[^"]*(")',
        lambda m: m.group(1) + sha_macos + m.group(2),
        content,
        flags=re.DOTALL,
    )

    # Update Linux URL
    content = re.sub(
        rf'url "{re.escape(base_url)}/[^"]*dart-docs-mcp-linux\.tar\.gz"',
        f'url "{base_url}/{tag}/dart-docs-mcp-linux.tar.gz"',
        content,
    )

    # Update Linux sha256 (inside the `elsif OS.linux?` block)
    content = re.sub(
        r'(elsif OS\.linux\?.*?sha256 ")[^"]*(")',
        lambda m: m.group(1) + sha_linux + m.group(2),
        content,
        flags=re.DOTALL,
    )

    with open(formula_path, "w") as f:
        f.write(content)

    print(f"Formula updated to version {version} ({tag})")
    print(f"  macOS sha256 : {sha_macos}")
    print(f"  Linux sha256 : {sha_linux}")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)

    _, formula_path, tag, sha_macos, sha_linux = sys.argv
    update_formula(formula_path, tag, sha_macos, sha_linux)
