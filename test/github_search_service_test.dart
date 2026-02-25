import 'package:test/test.dart';
import 'package:dart_docs_mcp/src/github_search_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  group('GithubSearchService', () {
    test('crossReferenceFeature flow with successful search', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('api.github.com/search/code')) {
          return http.Response(
            jsonEncode({
              'total_count': 2,
              'incomplete_results': false,
              'items': [
                {
                  'name': 'tool.dart',
                  'path': 'lib/src/models/tool.dart',
                  'sha': '123',
                  'url': 'http://api.github.com/tool.dart',
                  'git_url': 'http://api.github.com/tool.dart',
                  'html_url': 'http://github.com/tool.dart',
                  'repository': {
                    'id': 1,
                    'name': 'repo',
                    'full_name': 'owner/repo',
                    'private': false,
                    'html_url': 'http://github.com/owner/repo',
                  },
                  'score': 1.0,
                },
                {
                  'name': 'client.dart',
                  'path': 'lib/src/client.dart',
                  'sha': '456',
                  'url': 'http://api.github.com/client.dart',
                  'git_url': 'http://api.github.com/client.dart',
                  'html_url': 'http://github.com/client.dart',
                  'repository': {
                    'id': 1,
                    'name': 'repo',
                    'full_name': 'owner/repo',
                    'private': false,
                    'html_url': 'http://github.com/owner/repo',
                  },
                  'score': 0.9,
                },
              ],
            }),
            200,
          );
        } else if (request.url.toString().contains('pub.dev/api/packages')) {
          return http.Response(
            jsonEncode({
              'latest': {
                'pubspec': {'repository': 'https://github.com/owner/repo'},
              },
            }),
            200,
          );
        } else if (request.url.toString().contains('raw.githubusercontent.com')) {
          return http.Response('This package supports Function Calling.', 200);
        } else if (request.url.toString().contains('api.github.com/repos/')) {
          return http.Response(jsonEncode({'default_branch': 'main'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = GithubSearchService(client: mockClient);
      final result = await service.crossReferenceFeature(
        packageName: 'test_pkg',
        feature: 'Function Calling',
      );

      expect(result, contains('### Feature Implementation Mapping: "Function Calling"'));
      expect(result, contains('lib/src/models/tool.dart'));
      expect(result, contains('lib/src/client.dart'));
    });

    test('crossReferenceFeature handles no repo URL', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'latest': {'pubspec': {}},
          }),
          200,
        );
      });

      final service = GithubSearchService(client: mockClient);
      final result = await service.crossReferenceFeature(
        packageName: 'test_pkg',
        feature: 'Feature',
      );

      expect(result, contains('Could not find a valid repository URL'));
    });
  });
}
