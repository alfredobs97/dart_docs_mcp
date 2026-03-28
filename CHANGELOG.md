## 0.0.4

- Added new `get_changelog` tool: fetches and parses a targeted version range from a package's `CHANGELOG.md` to provide precise migration context.
- Enhanced error handling across `ArchivePubService` and `GithubPubService` to provide descriptive error messages for package/file discovery failures.
- Implemented `ChangelogParser` utility with robust regex-based extraction and fuzzy version matching.
- Added new `search_package_code` tool: performs a case-insensitive keyword or regex search across a package's internal `lib/` source files, returning file paths, 1-based line numbers, and ±3-line context snippets.
- Generated files (`.g.dart`, `.freezed.dart`, `.gr.dart`, `.mocks.dart`, `.config.dart`) are automatically excluded from search results to reduce noise.
- Search results are capped at 15 matches to prevent LLM context overflow.
- Updated README to document the new tools including parameter references and real output examples.

## 0.0.2

- Extended tool descriptions, prompts, and documentation to explicitly support Dart **and** Flutter packages.
- Updated `package_name` parameter descriptions with Flutter package examples (e.g., `flutter_bloc`).
- Added `GEMINI.md` with project context for AI agents.
- Updated `pubspec.yaml` description from boilerplate to a meaningful summary.

## 0.0.1

- Beta version.
