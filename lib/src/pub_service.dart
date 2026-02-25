abstract class PubService {
  /// Fetches package documentation for the given package name.
  /// Implementations should extract README.md and example/lib files.
  Future<String> getPackageDocs(String packageName);
}
