import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants/api_constants.dart';
import 'models/index.dart';

class GithubSearchService {
  final http.Client client;

  GithubSearchService({http.Client? client}) : client = client ?? http.Client();

  /// Maps a conceptual feature to its implementation in the repository.
  Future<String> crossReferenceFeature({
    required String packageName,
    required String feature,
  }) async {
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

      final branch = await _getDefaultBranch(owner, repo);
      final readmePath = pathPrefix == null ? 'README.md' : '$pathPrefix/README.md';
      final readme = await _fetchFile(owner, repo, branch, readmePath);

      if (readme == null) {
        return 'Could not find README.md for $packageName to extract keywords.';
      }

      final keywords = _extractKeywords(readme, feature);
      if (keywords.isEmpty) {
        // Fallback to feature name if no keywords extracted
        keywords.add(feature);
      }

      final searchQuery = _buildSearchQuery(keywords, owner, repo, pathPrefix);
      final searchResult = await _searchCode(searchQuery);

      if (searchResult.items.isEmpty) {
        return 'No implementation files found for feature "$feature" in $packageName.';
      }

      return _summarizeResults(feature, searchResult);
    } catch (e) {
      return 'Error during cross-referencing: $e';
    }
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

  List<String> _extractKeywords(String readme, String feature) {
    // Simple heuristic-based keyword extraction.
    // In a real scenario, this could be more sophisticated (e.g. using NLP).
    // For now, we look for matches near the feature description or common patterns.
    final keywords = <String>{};

    final featureLower = feature.toLowerCase();
    final lines = readme.split('\n');

    bool inFeatureSection = false;
    for (var line in lines) {
      final lineLower = line.toLowerCase();
      if (lineLower.contains(featureLower)) {
        inFeatureSection = true;
      } else if (line.startsWith('#') && inFeatureSection) {
        // Stop if we hit a new section
        inFeatureSection = false;
      }

      if (inFeatureSection) {
        // Extract CamelCase words or typical Dart terms
        final regex = RegExp(r'\b[A-Z][a-zA-Z0-9]+\b|\b[a-z]+(?:_[a-z]+)+\b');
        final matches = regex.allMatches(line);
        for (final match in matches) {
          final word = match.group(0)!;
          if (word.length > 3) keywords.add(word);
        }
      }
    }

    return keywords.take(5).toList();
  }

  String _buildSearchQuery(List<String> keywords, String owner, String repo, String? pathPrefix) {
    var query = keywords.join(' ');
    query += ' extension:dart path:lib/';
    if (pathPrefix != null) {
      query += ' path:$pathPrefix/lib/';
    }
    query += ' repo:$owner/$repo';
    return query;
  }

  Future<GithubSearchResult> _searchCode(String query) async {
    final url = Uri.parse(ApiConstants.githubSearchUrl(query));
    final response = await client.get(
      url,
      headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'dart-docs-mcp'},
    );

    if (response.statusCode != 200) {
      // Log or handle error
      return GithubSearchResult(totalCount: 0, incompleteResults: false, items: []);
    }

    return GithubSearchResult.fromJson(jsonDecode(response.body));
  }

  String _summarizeResults(String feature, GithubSearchResult result) {
    final buffer = StringBuffer();
    buffer.writeln('### Feature Implementation Mapping: "$feature"');
    buffer.writeln(
      'The requested feature is primarily implemented or defined in the following files:',
    );

    final coreImplementations = result.items
        .where((item) => item.path.contains('lib/src/'))
        .take(3)
        .toList();
    final exports = result.items
        .where((item) => !item.path.contains('lib/src/') && item.path.endsWith('.dart'))
        .take(2)
        .toList();

    if (coreImplementations.isNotEmpty) {
      buffer.writeln('\n**Core Implementation details:**');
      for (final item in coreImplementations) {
        buffer.writeln('- [${item.path}](${item.htmlUrl})');
      }
    }

    if (exports.isNotEmpty) {
      buffer.writeln('\n**Public API / Export Barrel files:**');
      for (final item in exports) {
        buffer.writeln('- [${item.path}](${item.htmlUrl})');
      }
    }

    if (coreImplementations.isEmpty && exports.isEmpty && result.items.isNotEmpty) {
      buffer.writeln('\n**Related files:**');
      for (final item in result.items.take(5)) {
        buffer.writeln('- [${item.path}](${item.htmlUrl})');
      }
    }

    return buffer.toString();
  }
}
