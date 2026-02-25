class ApiConstants {
  static String pubDevPackageUrl(String packageName) => 'https://pub.dev/api/packages/$packageName';

  static String githubRepoUrl(String owner, String repo) =>
      'https://api.github.com/repos/$owner/$repo';

  static String githubRawContentUrl(String owner, String repo, String branch, String path) =>
      'https://raw.githubusercontent.com/$owner/$repo/$branch/$path';

  static String githubContentsUrl(String owner, String repo, String branch, String dirPath) =>
      'https://api.github.com/repos/$owner/$repo/contents/$dirPath?ref=$branch';
}
