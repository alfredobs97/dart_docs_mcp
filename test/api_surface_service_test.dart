import 'package:test/test.dart';
import 'package:dart_docs_mcp/src/api_surface_service.dart';

void main() {
  group('ApiSurfaceService', () {
    late ApiSurfaceService service;

    setUp(() {
      service = ApiSurfaceService();
    });

    test(
      'fetches public API surface for the "http" package',
      () async {
        final surface = await service.getApiSurface('http');

        expect(surface, isNotEmpty);
        expect(surface, contains('package:http'));
        expect(surface, contains('// Package: http'));
        // The http package exposes a Client class
        expect(surface, contains('Client'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('filters API surface by class name', () async {
      final surface = await service.getApiSurface('http', className: 'Client');

      expect(surface, isNotEmpty);
      expect(surface, contains('// Filtered to: Client'));
      expect(surface, contains('Client'));
      // Should NOT contain unrelated top-level classes as containers
      expect(surface, isNot(contains('class Response {')));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test(
      'returns informative output for a non-existent package',
      () async {
        final surface = await service.getApiSurface('this_package_does_not_exist_xyz456');

        expect(surface, isNotEmpty);
        // Should contain an error or graceful message
        expect(surface, anyOf([contains('Error'), contains('No Dartdoc index found')]));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'fetches API surface for "riverpod" and contains provider-related symbols',
      () async {
        final surface = await service.getApiSurface('riverpod');

        expect(surface, isNotEmpty);
        expect(surface, contains('// Package: riverpod'));
        // riverpod exposes a Provider class
        expect(surface, contains('Provider'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
