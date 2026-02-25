import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'constants/api_constants.dart';
import 'models/github_repo_info.dart';

/// Result of a type hierarchy lookup.
class TypeHierarchyResult {
  /// The class modifiers line (e.g. "sealed class Part").
  final String? classSignature;

  /// Direct subclasses of the type.
  final List<String> subclasses;

  /// Classes that implement the type.
  final List<String> implementers;

  /// Classes that mix in this type.
  final List<String> mixedIn;

  /// The strategy that produced this result.
  final String strategy;

  /// Whether the type was a sealed class (affects guarantees about exhaustiveness).
  final bool isSealed;

  const TypeHierarchyResult({
    this.classSignature,
    required this.subclasses,
    required this.implementers,
    required this.mixedIn,
    required this.strategy,
    this.isSealed = false,
  });

  bool get isEmpty => subclasses.isEmpty && implementers.isEmpty && mixedIn.isEmpty;
}

/// Service that reconstructs the inheritance/implementation tree of a Dart class.
///
/// Uses a 3-strategy fallback approach:
/// 1. **Dartdoc HTML**: Scrapes pub.dev Dartdoc page (fastest, pre-computed hierarchy).
/// 2. **Sealed archive**: Downloads .tar.gz and parses the same file (for sealed classes).
/// 3. **GitHub code search**: Uses GitHub search API (for non-sealed types).
class TypeHierarchyService {
  final http.Client client;

  TypeHierarchyService({http.Client? client}) : client = client ?? http.Client();

  /// Returns a Markdown string describing the type hierarchy for [typeName] in [packageName].
  ///
  /// [namespace] is the library/namespace portion of the Dartdoc URL
  /// (e.g. 'characters' for the `characters` package, or 'dart-async' for `dart:async`).
  /// If null, multiple common namespaces are tried automatically.
  Future<String> getTypeHierarchy(String packageName, String typeName, {String? namespace}) async {
    final buffer = StringBuffer();
    buffer.writeln('# Type Hierarchy: $typeName ($packageName)');

    try {
      // Strategy 1: Dartdoc HTML scraping
      final dartdocResult = await _tryDartdocHtml(packageName, typeName, namespace);
      if (dartdocResult != null && !dartdocResult.isEmpty) {
        _writeResult(buffer, dartdocResult, typeName, packageName);
        return buffer.toString();
      }

      // Fetch pub.dev info once for strategies 2 and 3
      final pubInfo = await _fetchPubInfo(packageName);
      final archiveUrl = _extractArchiveUrl(pubInfo);
      final repoUrl = _extractRepoUrl(pubInfo);

      // Strategy 2: sealed class archive search
      if (archiveUrl != null) {
        final archiveResult = await _tryArchiveSearch(archiveUrl, typeName);
        if (archiveResult != null && !archiveResult.isEmpty) {
          _writeResult(buffer, archiveResult, typeName, packageName);
          return buffer.toString();
        }
      }

      // Strategy 3: GitHub code search
      if (repoUrl != null) {
        final githubInfo = _parseGithubUrl(repoUrl);
        if (githubInfo != null) {
          final githubResult = await _tryGithubSearch(githubInfo.owner, githubInfo.repo, typeName);
          if (githubResult != null && !githubResult.isEmpty) {
            _writeResult(buffer, githubResult, typeName, packageName);
            return buffer.toString();
          }
        }
      }

      buffer.writeln(
        '\nNo type hierarchy information found for `$typeName` in package `$packageName`.\n'
        'The type may not exist, or its documentation is not yet published on pub.dev.',
      );
    } catch (e) {
      buffer.writeln('\nError fetching type hierarchy: $e');
    }

    return buffer.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Strategy 1: Dartdoc HTML scraping
  // ─────────────────────────────────────────────────────────────────────────────

  Future<TypeHierarchyResult?> _tryDartdocHtml(
    String packageName,
    String typeName,
    String? namespace,
  ) async {
    // If a namespace is given, try it first; otherwise try the package name itself,
    // plus a few common patterns (dart-<name>, <packageName>/<typeName>).
    final candidates = <String>[?namespace, packageName, packageName.replaceAll('_', '-')];

    for (final ns in candidates) {
      final result = await _fetchDartdocPage(packageName, typeName, ns);
      if (result != null) return result;
    }
    return null;
  }

  Future<TypeHierarchyResult?> _fetchDartdocPage(
    String packageName,
    String typeName,
    String namespace,
  ) async {
    final url = ApiConstants.dartdocClassUrl(packageName, namespace, typeName);
    final response = await client.get(Uri.parse(url));
    if (response.statusCode != 200) return null;

    return _parseDartdocHtml(response.body, typeName);
  }

  TypeHierarchyResult? _parseDartdocHtml(String htmlContent, String typeName) {
    final document = html_parser.parse(htmlContent);

    // Extract class signature from the page header
    String? classSignature;
    final headerSpan = document.querySelector('h1.signature');
    if (headerSpan != null) {
      classSignature = headerSpan.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final isSealed = classSignature?.contains('sealed') ?? false;

    // Find the various hierarchy sections.
    // Dartdoc renders them as <section class="summary"> with an <h2> heading.
    final subclasses = <String>[];
    final implementers = <String>[];
    final mixedIn = <String>[];

    // Dartdoc sections we care about and where to put them
    final sectionMap = <String, List<String>>{
      'Subclasses': subclasses,
      'Implementers': implementers,
      'Mixed-in types': mixedIn,
      'Mixin applications': mixedIn,
    };

    final sections = document.querySelectorAll('section.summary');
    for (final section in sections) {
      final heading = section.querySelector('h2')?.text.trim() ?? '';
      final targetList = sectionMap[heading];
      if (targetList == null) continue;

      // Each entry is an <dt> tag containing a link or a code element
      for (final dt in section.querySelectorAll('dt')) {
        final link = dt.querySelector('a');
        if (link != null) {
          final name = link.text.trim();
          if (name.isNotEmpty) targetList.add(name);
        } else {
          final code = dt.querySelector('span.name, code');
          if (code != null) {
            final name = code.text.trim();
            if (name.isNotEmpty) targetList.add(name);
          }
        }
      }
    }

    // If nothing found in <section> tags, try simpler <dl> approach
    if (subclasses.isEmpty && implementers.isEmpty && mixedIn.isEmpty) {
      final allH2 = document.querySelectorAll('h2');
      for (final h2 in allH2) {
        final heading = h2.text.trim();
        final targetList = sectionMap[heading];
        if (targetList == null) continue;

        // Look for adjacent <dl> sibling
        var sibling = h2.nextElementSibling;
        while (sibling != null) {
          if (sibling.localName == 'dl') {
            for (final dt in sibling.querySelectorAll('dt')) {
              final link = dt.querySelector('a');
              final name = link?.text.trim() ?? dt.text.trim();
              if (name.isNotEmpty && name != heading) targetList.add(name);
            }
            break;
          } else if (sibling.localName == 'h2') {
            break;
          }
          sibling = sibling.nextElementSibling;
        }
      }
    }

    // Check if the page was actually found (minimal content check)
    if (classSignature == null && subclasses.isEmpty && implementers.isEmpty && mixedIn.isEmpty) {
      return null;
    }

    return TypeHierarchyResult(
      classSignature: classSignature,
      subclasses: subclasses,
      implementers: implementers,
      mixedIn: mixedIn,
      strategy: 'dartdoc',
      isSealed: isSealed,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Strategy 2: Archive / sealed class search
  // ─────────────────────────────────────────────────────────────────────────────

  Future<TypeHierarchyResult?> _tryArchiveSearch(String archiveUrl, String typeName) async {
    final response = await client.get(Uri.parse(archiveUrl));
    if (response.statusCode != 200) return null;

    final tarBytes = GZipDecoder().decodeBytes(response.bodyBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    // Find the file declaring the type
    String? declaringFileContent;
    String? declaringFileName;
    bool isSealed = false;

    for (final file in archive) {
      if (!file.isFile || !file.name.endsWith('.dart')) continue;
      final content = utf8.decode(file.content as List<int>, allowMalformed: true);

      // Look for sealed/abstract class declaration
      final sealedPattern = RegExp(
        r'\b(sealed|abstract|base|interface|final)\s+class\s+' + RegExp.escape(typeName) + r'\b',
      );
      final plainPattern = RegExp(r'\bclass\s+' + RegExp.escape(typeName) + r'\b');

      if (sealedPattern.hasMatch(content)) {
        isSealed = content.contains(
          RegExp(r'\bsealed\s+class\s+' + RegExp.escape(typeName) + r'\b'),
        );
        declaringFileContent = content;
        declaringFileName = file.name;
        break;
      } else if (plainPattern.hasMatch(content) && declaringFileContent == null) {
        declaringFileContent = content;
        declaringFileName = file.name;
        // Keep looking for sealed declaration
      }
    }

    if (declaringFileContent == null) return null;

    // For sealed classes: parse subclasses in the same file (+ part files)
    final subclasses = <String>[];
    final implementers = <String>[];
    final mixedIn = <String>[];

    _extractRelationships(declaringFileContent, typeName, subclasses, implementers, mixedIn);

    // If sealed, also check part files referenced within the archive
    if (isSealed) {
      final partPattern = RegExp(r"^\s*part\s+'([^']+)'\s*;", multiLine: true);
      final basePath = declaringFileName!.contains('/')
          ? declaringFileName.substring(0, declaringFileName.lastIndexOf('/') + 1)
          : '';

      for (final match in partPattern.allMatches(declaringFileContent)) {
        final partPath = '$basePath${match.group(1)}';
        // Find the part file in the archive
        for (final file in archive) {
          if (file.isFile && file.name.endsWith(partPath)) {
            final partContent = utf8.decode(file.content as List<int>, allowMalformed: true);
            _extractRelationships(partContent, typeName, subclasses, implementers, mixedIn);
            break;
          }
        }
      }
    }

    return TypeHierarchyResult(
      subclasses: subclasses.toSet().toList(),
      implementers: implementers.toSet().toList(),
      mixedIn: mixedIn.toSet().toList(),
      strategy: 'archive',
      isSealed: isSealed,
    );
  }

  void _extractRelationships(
    String content,
    String typeName,
    List<String> subclasses,
    List<String> implementers,
    List<String> mixedIn,
  ) {
    // Match: class Foo extends TypeName
    final extendsPattern = RegExp(
      r'\bclass\s+(\w+)(?:<[^>]*>)?\s+extends\s+' + RegExp.escape(typeName) + r'\b',
    );
    for (final m in extendsPattern.allMatches(content)) {
      final name = m.group(1);
      if (name != null && name != typeName) subclasses.add(name);
    }

    // Match: class Foo implements TypeName
    final implementsPattern = RegExp(
      r'\bclass\s+(\w+)(?:<[^>]*>)?(?:\s+\w+\s+\w+)*\s+implements\s+[^{]*\b' +
          RegExp.escape(typeName) +
          r'\b',
    );
    for (final m in implementsPattern.allMatches(content)) {
      final name = m.group(1);
      if (name != null && name != typeName) implementers.add(name);
    }

    // Match: class Foo with TypeName / mixin Foo on TypeName
    final withPattern = RegExp(
      r'\bclass\s+(\w+)(?:<[^>]*>)?(?:\s+\w+\s+\w+)*\s+with\s+[^{]*\b' +
          RegExp.escape(typeName) +
          r'\b',
    );
    for (final m in withPattern.allMatches(content)) {
      final name = m.group(1);
      if (name != null && name != typeName) mixedIn.add(name);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Strategy 3: GitHub code search
  // ─────────────────────────────────────────────────────────────────────────────

  Future<TypeHierarchyResult?> _tryGithubSearch(String owner, String repo, String typeName) async {
    final query =
        '"extends $typeName" OR "implements $typeName" OR "with $typeName" '
        'extension:dart repo:$owner/$repo';
    final url = ApiConstants.githubCodeSearchUrl(query);

    final response = await client.get(
      Uri.parse(url),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];

    final subclasses = <String>[];
    final implementers = <String>[];
    final mixedIn = <String>[];

    for (final item in items) {
      final fileUrl = item['html_url'] as String?;
      if (fileUrl == null) continue;

      // Convert HTML URL to raw URL to fetch file content
      final rawUrl = fileUrl
          .replaceFirst('github.com', 'raw.githubusercontent.com')
          .replaceFirst('/blob/', '/');

      final fileResponse = await client.get(Uri.parse(rawUrl));
      if (fileResponse.statusCode == 200) {
        _extractRelationships(fileResponse.body, typeName, subclasses, implementers, mixedIn);
      }
    }

    return TypeHierarchyResult(
      subclasses: subclasses.toSet().toList(),
      implementers: implementers.toSet().toList(),
      mixedIn: mixedIn.toSet().toList(),
      strategy: 'github_search',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Output formatting
  // ─────────────────────────────────────────────────────────────────────────────

  void _writeResult(
    StringBuffer buffer,
    TypeHierarchyResult result,
    String typeName,
    String packageName,
  ) {
    if (result.classSignature != null) {
      buffer.writeln('\n## Class Signature');
      buffer.writeln('```dart');
      buffer.writeln(result.classSignature);
      buffer.writeln('```');
    }

    if (result.isSealed) {
      buffer.writeln(
        '\n> ⚠️ **Sealed class**: All direct subclasses are exhaustively listed below. '
        'Use an exhaustive `switch` expression covering all of them.',
      );
    }

    if (result.subclasses.isNotEmpty) {
      buffer.writeln('\n## Subclasses');
      for (final name in result.subclasses) {
        buffer.writeln('- `$name`');
      }
    }

    if (result.implementers.isNotEmpty) {
      buffer.writeln('\n## Implementers');
      for (final name in result.implementers) {
        buffer.writeln('- `$name`');
      }
    }

    if (result.mixedIn.isNotEmpty) {
      buffer.writeln('\n## Mixed-in by');
      for (final name in result.mixedIn) {
        buffer.writeln('- `$name`');
      }
    }

    buffer.writeln('\n---');
    buffer.writeln('_Source: ${result.strategy}_');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Pub.dev helpers
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchPubInfo(String packageName) async {
    final url = Uri.parse(ApiConstants.pubDevPackageUrl(packageName));
    final response = await client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load package info from pub.dev: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String? _extractArchiveUrl(Map<String, dynamic> pubInfo) {
    final latest = pubInfo['latest'];
    if (latest == null) return null;
    final archiveUrl = latest['archive_url'];
    if (archiveUrl is String && archiveUrl.isNotEmpty) return archiveUrl;
    return null;
  }

  String? _extractRepoUrl(Map<String, dynamic> pubInfo) {
    final latest = pubInfo['latest']?['pubspec'];
    if (latest == null) return null;
    final repo = latest['repository'];
    if (repo is String && repo.isNotEmpty) return repo;
    final homepage = latest['homepage'];
    if (homepage is String && homepage.isNotEmpty) return homepage;
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
    } catch (_) {
      return null;
    }
  }
}
