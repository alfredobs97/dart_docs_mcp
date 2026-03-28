abstract class PubService {
  /// Fetches package documentation for the given package name.
  /// Implementations should extract README.md and example/lib files.
  Future<String> getPackageDocs(String packageName);

  /// Fetches the CHANGELOG.md file for the given package name.
  Future<String?> getChangelog(String packageName);
}
