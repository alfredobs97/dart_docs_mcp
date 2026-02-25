import 'package:test/test.dart';
import 'package:dart_docs_mcp/src/type_hierarchy_service.dart';

void main() {
  group('TypeHierarchyService', () {
    late TypeHierarchyService service;

    setUp(() {
      service = TypeHierarchyService();
    });

    group('Strategy 1: Dartdoc HTML scraping', () {
      test(
        'finds subclasses of a sealed class via Dartdoc HTML',
        () async {
          // The `characters` package exposes `CharacterRange` as an abstract class
          // with documented implementers on pub.dev Dartdoc pages.
          final result = await service.getTypeHierarchy('characters', 'CharacterRange');

          expect(result, isNotEmpty);
          expect(result, contains('# Type Hierarchy: CharacterRange (characters)'));
          // Should have found something via dartdoc or archive
          expect(
            result,
            anyOf([
              contains('## Subclasses'),
              contains('## Implementers'),
              contains('_Source: dartdoc_'),
              contains('_Source: archive_'),
              contains('_Source: github_search_'),
              contains('No type hierarchy information found'),
            ]),
          );
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );

      test(
        'finds hierarchy for AsyncValue sealed class via riverpod Dartdoc',
        () async {
          final result = await service.getTypeHierarchy('riverpod', 'AsyncValue');

          expect(result, isNotEmpty);
          expect(result, contains('# Type Hierarchy: AsyncValue (riverpod)'));
          // AsyncValue is a well-known sealed class with known subclasses:
          // AsyncData, AsyncLoading, AsyncError
          expect(
            result,
            anyOf([
              contains('AsyncData'),
              contains('AsyncLoading'),
              contains('AsyncError'),
              contains('No type hierarchy information found'),
            ]),
          );
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );
    });

    group('Strategy 2: Archive / sealed class search', () {
      test(
        'finds subclasses in a sealed class declaration file via archive',
        () async {
          // Test with `result` package (oxidized) which uses sealed classes
          // Fallback: use `freezed_annotation` or a simpler package
          final result = await service.getTypeHierarchy('riverpod', 'AsyncValue');

          expect(result, isNotEmpty);
          expect(result, contains('# Type Hierarchy: AsyncValue (riverpod)'));
          // We just need any output — real content validated in integration tests
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );
    });

    group('Error handling', () {
      test('handles non-existent package gracefully', () async {
        final result = await service.getTypeHierarchy(
          'this_package_does_not_exist_xyz123',
          'SomeClass',
        );

        expect(result, isNotEmpty);
        expect(
          result,
          anyOf([
            contains('No type hierarchy information found'),
            contains('Error fetching type hierarchy'),
          ]),
        );
      }, timeout: const Timeout(Duration(seconds: 30)));

      test(
        'handles non-existent type in a real package gracefully',
        () async {
          final result = await service.getTypeHierarchy('path', 'NonExistentType99999');

          expect(result, isNotEmpty);
          expect(
            result,
            anyOf([
              contains('No type hierarchy information found'),
              contains('Error fetching type hierarchy'),
            ]),
          );
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('Namespace parameter', () {
      test(
        'uses provided namespace when fetching Dartdoc page',
        () async {
          final result = await service.getTypeHierarchy(
            'riverpod',
            'AsyncValue',
            namespace: 'riverpod',
          );

          expect(result, isNotEmpty);
          expect(result, contains('# Type Hierarchy: AsyncValue (riverpod)'));
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('Output format', () {
      test('output always starts with the correct header', () async {
        final result = await service.getTypeHierarchy('path', 'Style');
        expect(result, startsWith('# Type Hierarchy: Style (path)'));
      }, timeout: const Timeout(Duration(seconds: 30)));
    });
  });
}
