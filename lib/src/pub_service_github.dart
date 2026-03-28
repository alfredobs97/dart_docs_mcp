import 'dart:convert';
import 'package:http/http.dart' as http;

import 'constants/api_constants.dart';
import 'models/index.dart';
import 'pub_service.dart';

class GithubPubService implements PubService {
  final http.Client client;

  GithubPubService({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<String> getPackageDocs(String packageName) async {
    final buffer = StringBuffer();
    buffer.writeln('# Documentation context for $packageName');

    try {
      final pubInfo = await _fetchPubInfo(packageName);
      final repoUrl = _extractRepoUrl(pubInfo);

      if (repoUrl == null) {
        return 'Could not find a valid repository URL for $packageName.';
      }

      final githubInfo = _parseGithubUrl(repoUrl);
      if (githubInfo == null) {
        return 'The repository URL is not a standard GitHub URL: $repoUrl';
      }

      final String owner = githubInfo.owner;
      final String repo = githubInfo.repo;
      final String? pathPrefix = githubInfo.pathPrefix;

      // Get Default Branch
      final String branch = await _getDefaultBranch(owner, repo);

      // Fetch Root README
      final readmePath = pathPrefix == null ? 'README.md' : '$pathPrefix/README.md';
      var readme = await _fetchFile(owner, repo, branch, readmePath);

      if (readme != null) {
        // Check for repository redirection
        final redirectUrl = _extractRedirectUrl(readme);
        if (redirectUrl != null) {
          final redirectedInfo = _parseGithubUrl(redirectUrl);
          if (redirectedInfo != null) {
            // Recurse into the new repository
            final redirectedDocs = await getPackageDocsFromInfo(
              packageName,
              redirectedInfo.owner,
              redirectedInfo.repo,
              redirectedInfo.pathPrefix,
            );
            return redirectedDocs;
          }
        }

        buffer.writeln('\n## README.md');
        buffer.writeln(readme);
      } else {
        buffer.writeln('\nNo main README.md found.');
      }

      // Fetch Example README
      final exampleReadmePath = pathPrefix == null
          ? 'example/README.md'
          : '$pathPrefix/example/README.md';
      final exampleReadme = await _fetchFile(owner, repo, branch, exampleReadmePath);
      if (exampleReadme != null) {
        buffer.writeln('\n## example/README.md');
        buffer.writeln(exampleReadme);
      }

      // Fetch example/lib
      final exampleLibPrefix = pathPrefix == null ? 'example/lib' : '$pathPrefix/example/lib';
      final exampleLibFiles = await _fetchDirectoryFiles(owner, repo, branch, exampleLibPrefix);

      if (exampleLibFiles.isEmpty) {
        buffer.writeln('\nNo example/lib files found.');
      } else {
        buffer.writeln('\n## example/lib Files');
        for (final entry in exampleLibFiles.entries) {
          buffer.writeln('\n### ${entry.key}');
          buffer.writeln('```dart\n${entry.value}\n```');
        }
      }
    } catch (e) {
      buffer.writeln('Error fetching documentation: $e');
    }

    return buffer.toString();
  }

  @override
  Future<String?> getChangelog(String packageName) async {
    try {
      final pubInfo = await _fetchPubInfo(packageName);
      final repoUrl = _extractRepoUrl(pubInfo);

      if (repoUrl == null) {
        throw Exception('No repository URL linked to package $packageName on pub.dev.');
      }

      final githubInfo = _parseGithubUrl(repoUrl);
      if (githubInfo == null) {
        throw Exception('Could not parse GitHub repository from URL: $repoUrl for package $packageName.');
      }

      final String owner = githubInfo.owner;
      final String repo = githubInfo.repo;
      final String? pathPrefix = githubInfo.pathPrefix;

      final String branch = await _getDefaultBranch(owner, repo);

      final changelogPath =
          pathPrefix == null ? 'CHANGELOG.md' : '$pathPrefix/CHANGELOG.md';

      final content = await _fetchFile(owner, repo, branch, changelogPath);
      if (content == null || content.isEmpty) {
        throw Exception('CHANGELOG.md not found in the GitHub repository at $changelogPath for $packageName.');
      }
      return content;
    } catch (e) {
      if (e is Exception) rethrow; // Preserve original exceptions
      throw Exception('Error fetching changelog for $packageName: $e');
    }
  }

  /// Internal helper to fetch docs when owner/repo/path are already known.
  Future<String> getPackageDocsFromInfo(
    String packageName,
    String owner,
    String repo,
    String? pathPrefix,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('# Documentation context for $packageName');

    try {
      final branch = await _getDefaultBranch(owner, repo);

      // Root README
      final readmePath = pathPrefix == null ? 'README.md' : '$pathPrefix/README.md';
      final readme = await _fetchFile(owner, repo, branch, readmePath);
      if (readme != null) {
        buffer.writeln('\n## README.md');
        buffer.writeln(readme);
      }

      // Example README
      final exampleReadmePath = pathPrefix == null
          ? 'example/README.md'
          : '$pathPrefix/example/README.md';
      final exampleReadme = await _fetchFile(owner, repo, branch, exampleReadmePath);
      if (exampleReadme != null) {
        buffer.writeln('\n## example/README.md');
        buffer.writeln(exampleReadme);
      }

      // example/lib
      final exampleLibPrefix = pathPrefix == null ? 'example/lib' : '$pathPrefix/example/lib';
      final exampleLibFiles = await _fetchDirectoryFiles(owner, repo, branch, exampleLibPrefix);

      if (exampleLibFiles.isNotEmpty) {
        buffer.writeln('\n## example/lib Files');
        for (final entry in exampleLibFiles.entries) {
          buffer.writeln('\n### ${entry.key}');
          buffer.writeln('```dart\n${entry.value}\n```');
        }
      }
    } catch (e) {
      buffer.writeln('Error fetching redirected documentation: $e');
    }

    return buffer.toString();
  }

  String? _extractRedirectUrl(String readmeContent) {
    if (!readmeContent.contains('This package has been moved to a new repository:')) {
      return null;
    }

    // Try to find the URL in the text
    final urlMatch = RegExp(r'https://github\.com/[^\s\n\)]+').firstMatch(readmeContent);
    return urlMatch?.group(0);
  }

  Future<Map<String, dynamic>> _fetchPubInfo(String packageName) async {
    final url = Uri.parse(ApiConstants.pubDevPackageUrl(packageName));
    final response = await client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load package info from pub.dev: ${response.statusCode}');
    }
    return jsonDecode(response.body);
  }

  String? _extractRepoUrl(Map<String, dynamic> pubInfo) {
    final latest = pubInfo['latest']?['pubspec'];
    if (latest == null) return null;

    final repo = latest['repository'];
    if (repo != null && repo is String && repo.isNotEmpty) return repo;

    final homepage = latest['homepage'];
    if (homepage != null && homepage is String && homepage.isNotEmpty) return homepage;

    return null;
  }

  GithubRepoInfo? _parseGithubUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host != 'github.com') return null;

      final segments = uri.pathSegments;
      if (segments.length < 2) return null;

      final owner = segments[0];
      final repo = segments[1].replaceAll('.git', '');

      String? path;
      if (segments.length > 4 && segments[2] == 'tree') {
        path = segments.sublist(4).join('/');
      }

      return GithubRepoInfo(owner: owner, repo: repo, pathPrefix: path);
    } catch (e) {
      return null;
    }
  }

  Future<String> _getDefaultBranch(String owner, String repo) async {
    final url = Uri.parse(ApiConstants.githubRepoUrl(owner, repo));
    final response = await client.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['default_branch'] ?? 'main';
    }
    return 'main';
  }

  Future<String?> _fetchFile(String owner, String repo, String branch, String path) async {
    final url = Uri.parse(ApiConstants.githubRawContentUrl(owner, repo, branch, path));
    final response = await client.get(url);
    if (response.statusCode == 200) {
      return response.body;
    }
    return null;
  }

  Future<Map<String, String>> _fetchDirectoryFiles(
    String owner,
    String repo,
    String branch,
    String dirPath,
  ) async {
    final results = <String, String>{};

    // Using GitHub API to list contents
    final url = Uri.parse(ApiConstants.githubContentsUrl(owner, repo, branch, dirPath));
    final response = await client.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      if (data is List) {
        for (final item in data) {
          final node = GithubContentNode.fromJson(item as Map<String, dynamic>);

          if (node.isFile && node.downloadUrl != null) {
            if (node.name.endsWith('.dart') ||
                node.name.endsWith('.yaml') ||
                node.name.endsWith('.md')) {
              // only text files
              final fileResponse = await client.get(Uri.parse(node.downloadUrl!));
              if (fileResponse.statusCode == 200) {
                results[node.path] = fileResponse.body;
              }
            }
          } else if (node.isDirectory) {
            final subResults = await _fetchDirectoryFiles(owner, repo, branch, node.path);
            results.addAll(subResults);
          }
        }
      }
    }

    return results;
  }
}
