import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:dart_docs_mcp/src/models/index.dart';
import 'package:http/http.dart' as http;

import 'constants/api_constants.dart';
import 'pub_service.dart';

class ArchivePubService implements PubService {
  final http.Client client;

  ArchivePubService({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<String> getPackageDocs(String packageName) async {
    final buffer = StringBuffer();
    buffer.writeln('# Documentation context for $packageName');

    try {
      final pubInfo = await _fetchPubInfo(packageName);
      final archiveUrl = _extractArchiveUrl(pubInfo);

      if (archiveUrl == null) {
        return 'Could not find a valid archive URL for $packageName.';
      }

      final url = Uri.parse(archiveUrl);
      final response = await client.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to download archive for $packageName: ${response.statusCode}');
      }

      // Decode the gzip-compressed tar archive.
      final tarBytes = GZipDecoder().decodeBytes(response.bodyBytes);
      final archive = TarDecoder().decodeBytes(tarBytes);

      String? readmeContent;
      String? exampleReadmeContent;
      final exampleLibFiles = <String, String>{};

      for (final file in archive) {
        if (file.isFile) {
          final contentBytes = file.content as List<int>;
          final contentString = utf8.decode(contentBytes, allowMalformed: true);

          if (file.name == 'README.md') {
            readmeContent = contentString;
          } else if (file.name == 'example/README.md') {
            exampleReadmeContent = contentString;
          } else if (file.name.startsWith('example/lib/') &&
              (file.name.endsWith('.dart') ||
                  file.name.endsWith('.md') ||
                  file.name.endsWith('.yaml'))) {
            exampleLibFiles[file.name] = contentString;
          }
        }
      }

      if (readmeContent != null) {
        buffer.writeln('\\n## README.md');
        buffer.writeln(readmeContent);
      } else {
        buffer.writeln('\\nNo main README.md found.');
      }

      if (exampleReadmeContent != null) {
        buffer.writeln('\n## example/README.md');
        buffer.writeln(exampleReadmeContent);
      }

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

  /// Searches through the `lib/` source files of [packageName] for lines
  /// matching [searchQuery] (case-insensitive).
  ///
  /// Generated files (e.g. `*.g.dart`, `*.freezed.dart`) are excluded.
  /// Returns at most [maxMatches] results (default 15), each with the file
  /// path, 1-based line number, and a ±3-line context snippet.
  Future<List<SearchMatch>> searchPackageCode(
    String packageName,
    String searchQuery, {
    int maxMatches = 15,
  }) async {
    final pubInfo = await _fetchPubInfo(packageName);
    final archiveUrl = _extractArchiveUrl(pubInfo);

    if (archiveUrl == null) {
      throw Exception('Could not find a valid archive URL for $packageName.');
    }

    final url = Uri.parse(archiveUrl);
    final response = await client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to download archive for $packageName: ${response.statusCode}');
    }

    final tarBytes = GZipDecoder().decodeBytes(response.bodyBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    final pattern = RegExp(searchQuery, caseSensitive: false);
    final matches = <SearchMatch>[];

    for (final file in archive) {
      if (matches.length >= maxMatches) break;

      if (!file.isFile) continue;
      if (!file.name.startsWith('lib/')) continue;
      if (!file.name.endsWith('.dart')) continue;
      if (_isGeneratedFile(file.name)) continue;

      final contentBytes = file.content as List<int>;
      final contentString = utf8.decode(contentBytes, allowMalformed: true);
      final lines = contentString.split('\n');

      for (var i = 0; i < lines.length; i++) {
        if (matches.length >= maxMatches) break;

        if (!pattern.hasMatch(lines[i])) continue;

        final contextStart = (i - 3).clamp(0, lines.length - 1);
        final contextEnd = (i + 3).clamp(0, lines.length - 1);

        final snippetLines = <String>[];
        for (var j = contextStart; j <= contextEnd; j++) {
          final prefix = j == i ? '>>> ' : '    ';
          snippetLines.add('${prefix}L${j + 1}: ${lines[j]}');
        }

        matches.add(
          SearchMatch(filePath: file.name, lineNumber: i + 1, snippet: snippetLines.join('\n')),
        );
      }
    }

    return matches;
  }

  /// Returns `true` for common generated Dart file suffixes that should be
  /// excluded from code searches to avoid noisy, machine-written results.
  bool _isGeneratedFile(String path) {
    const generatedSuffixes = [
      '.g.dart',
      '.freezed.dart',
      '.gr.dart',
      '.mocks.dart',
      '.config.dart',
    ];
    return generatedSuffixes.any((suffix) => path.endsWith(suffix));
  }

  Future<Map<String, dynamic>> _fetchPubInfo(String packageName) async {
    final url = Uri.parse(ApiConstants.pubDevPackageUrl(packageName));
    final response = await client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load package info from pub.dev: ${response.statusCode}');
    }
    return jsonDecode(response.body);
  }

  String? _extractArchiveUrl(Map<String, dynamic> pubInfo) {
    // latest matches to the latest publication object from pub API
    final latest = pubInfo['latest'];
    if (latest == null) return null;

    final archiveUrl = latest['archive_url'];
    if (archiveUrl != null && archiveUrl is String && archiveUrl.isNotEmpty) {
      return archiveUrl;
    }

    return null;
  }
}
