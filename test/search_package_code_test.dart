import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dart_docs_mcp/src/pub_service_archive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal `.tar.gz` archive bytes from a map of
/// { entryName -> fileContent } so tests don't need real network access.
List<int> _buildArchive(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  final tarBytes = TarEncoder().encode(archive);
  return GZipEncoder().encode(tarBytes);
}

/// Creates a [MockClient] that:
/// - returns [pubInfoJson] for pub.dev API requests
/// - returns [archiveBytes] for the archive download URL
MockClient _mockClient({
  required Map<String, dynamic> pubInfoJson,
  required List<int> archiveBytes,
}) {
  return MockClient((request) async {
    if (request.url.host == 'pub.dev') {
      return http.Response(jsonEncode(pubInfoJson), 200);
    }
    if (request.url.toString().contains('archive')) {
      return http.Response.bytes(archiveBytes, 200);
    }
    return http.Response('Not Found', 404);
  });
}

/// Standard pub.dev API response pointing at a fake archive URL.
Map<String, dynamic> get _fakePubInfo => {
  'latest': {
    'archive_url': 'https://fake.archive/pkg-1.0.0.tar.gz',
    'pubspec': {'name': 'pkg'},
  },
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ArchivePubService.searchPackageCode', () {
    test('returns matches with correct file path, line number and snippet', () async {
      final archive = _buildArchive({
        'lib/src/client.dart': '''
import 'dart:io';

class HttpClient {
  Future<void> get(String url) async {
    // perform request
  }
}
''',
      });

      final service = ArchivePubService(
        client: _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive),
      );

      final matches = await service.searchPackageCode('pkg', 'HttpClient');

      expect(matches, isNotEmpty);
      expect(matches.first.filePath, 'lib/src/client.dart');
      // 'class HttpClient' is on line 3
      expect(matches.first.lineNumber, 3);
      expect(matches.first.snippet, contains('>>> L3:'));
      expect(matches.first.snippet, contains('HttpClient'));
    });

    test('search is case-insensitive', () async {
      final archive = _buildArchive({
        'lib/src/util.dart': 'String formatDate(DateTime dt) => dt.toString();',
      });

      final service = ArchivePubService(
        client: _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive),
      );

      final matches = await service.searchPackageCode('pkg', 'FORMATDATE');
      expect(matches, hasLength(1));
      expect(matches.first.snippet, contains('formatDate'));
    });

    test('returns empty list when no matches found', () async {
      final archive = _buildArchive({'lib/src/util.dart': 'void main() => print("hello");'});

      final service = ArchivePubService(
        client: _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive),
      );

      final matches = await service.searchPackageCode('pkg', 'ThisSymbolDoesNotExist');
      expect(matches, isEmpty);
    });

    test('excludes generated files', () async {
      final archive = _buildArchive({
        // Generated — must be excluded
        'lib/src/model.g.dart': 'String fromJson() => "generated";',
        'lib/src/model.freezed.dart': 'class \$Model {}',
        'lib/src/router.gr.dart': 'class FakeRouter {}',
        'lib/test.mocks.dart': 'class MockService {}',
        'lib/injection.config.dart': 'void configureDependencies() {}',
        // Real source — should be included
        'lib/src/model.dart': 'class Model { String name = ""; }',
      });

      final service = ArchivePubService(
        client: _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive),
      );

      // Search for something present in both generated and real files
      final matches = await service.searchPackageCode('pkg', 'class');
      // Only the real model.dart should match
      expect(matches, hasLength(1));
      expect(matches.first.filePath, 'lib/src/model.dart');
    });

    test('caps results at the maxMatches limit', () async {
      // Create a file with 20 matching lines
      final lines = List.generate(20, (i) => 'void fn$i() => doSomething();').join('\n');
      final archive = _buildArchive({'lib/src/many.dart': lines});

      final service = ArchivePubService(
        client: _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive),
      );

      final matches = await service.searchPackageCode('pkg', 'doSomething', maxMatches: 5);
      expect(matches, hasLength(5));
    });

    test('throws when the package does not exist (HTTP 404)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = ArchivePubService(client: mockClient);

      expect(
        () => service.searchPackageCode('nonexistent_pkg_xyz', 'anything'),
        throwsA(isA<Exception>()),
      );
    });

    test('snippet includes context lines around the match', () async {
      final archive = _buildArchive({
        'lib/src/context.dart': '''line1
line2
line3
TARGET_LINE
line5
line6
line7
''',
      });

      final service = ArchivePubService(
        client: _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive),
      );

      final matches = await service.searchPackageCode('pkg', 'TARGET_LINE');
      expect(matches, hasLength(1));

      final snippet = matches.first.snippet;
      // Should contain the 3 lines before and after the match
      expect(snippet, contains('L1:'));
      expect(snippet, contains('L2:'));
      expect(snippet, contains('L3:'));
      expect(snippet, contains('>>> L4:')); // the matching line
      expect(snippet, contains('L5:'));
      expect(snippet, contains('L6:'));
      expect(snippet, contains('L7:'));
    });
  });

  group('SearchPackageCodeTool output formatting', () {
    test('formats no-match response correctly', () async {
      final archive = _buildArchive({'lib/src/a.dart': 'void main() {}'});

      final mockClient = _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive);

      final service = ArchivePubService(client: mockClient);
      final matches = await service.searchPackageCode('pkg', 'zzz_no_match');

      expect(matches, isEmpty);
    });

    test('formats match response with heading and code fences', () async {
      final archive = _buildArchive({
        'lib/src/widget.dart': 'class MyWidget extends StatelessWidget {}',
      });

      final service = ArchivePubService(
        client: _mockClient(pubInfoJson: _fakePubInfo, archiveBytes: archive),
      );

      final matches = await service.searchPackageCode('pkg', 'MyWidget');
      expect(matches, hasLength(1));
      expect(matches.first.filePath, contains('widget.dart'));
    });
  });
}
