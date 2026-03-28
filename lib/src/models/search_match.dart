/// A single match found by [ArchivePubService.searchPackageCode].
class SearchMatch {
  /// Path of the file within the package archive (e.g. `lib/src/client.dart`).
  final String filePath;

  /// 1-based line number of the matching line.
  final int lineNumber;

  /// Surrounding context: up to 3 lines before and after the match, joined
  /// by newlines. The matching line itself is prefixed with `>>>`.
  final String snippet;

  const SearchMatch({required this.filePath, required this.lineNumber, required this.snippet});
}
