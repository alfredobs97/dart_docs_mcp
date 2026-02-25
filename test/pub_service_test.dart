import 'package:test/test.dart';
import 'package:dart_docs_mcp/src/pub_service_github.dart';
import 'package:dart_docs_mcp/src/pub_service_archive.dart';

void main() {
  group('PubService implementations', () {
    test(
      'GithubPubService fetches documentation for a package via GitHub',
      () async {
        final service = GithubPubService();
        final docs = await service.getPackageDocs('path');

        expect(docs, isNotEmpty);
        expect(docs, contains('# Documentation context for path'));
        expect(docs, contains('## README.md'));
        // The path package may not have example/lib, so we check broadly
        expect(
          docs,
          anyOf([
            contains('## example/README.md'),
            contains('## example/lib Files'),
            contains('No example/lib files found.'),
          ]),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'ArchivePubService fetches documentation for a package via Archive',
      () async {
        final service = ArchivePubService();
        // Using feedback here since it's known to have example/lib inside an archive
        final docs = await service.getPackageDocs('feedback');

        expect(docs, isNotEmpty);
        expect(docs, contains('# Documentation context for feedback'));
        expect(docs, contains('## README.md'));
        // The feedback package has examples
        expect(docs, contains('## example/lib Files'));
        // Main.dart is typical
        expect(docs, contains('main.dart'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'GithubPubService handles gracefully a moved repository override (googleai_dart)',
      () async {
        final service = GithubPubService();
        final docs = await service.getPackageDocs('googleai_dart');

        expect(docs, isNotEmpty);
        expect(docs, contains('# Documentation context for googleai_dart'));
        // It should follow the redirect to the ai_clients_dart monorepo and actually pull the full README
        expect(docs, isNot(contains('This package has been moved to a new repository:')));
        // Expect some standard dart README content that wouldn't be in the tiny moved stub
        expect(docs, contains('##'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('ArchivePubService handles non-existent packages gracefully', () async {
      final service = ArchivePubService();
      final docs = await service.getPackageDocs('this_package_does_not_exist_xyz123');
      expect(docs, contains('Error fetching documentation'));
    });
  });
}
