import 'package:test/test.dart';
import 'package:dart_docs_mcp/mcp/mcp.dart';

void main() {
  group('DartDocsServer initialization via createMcpServer', () {
    test('Can instantiate server', () {
      final server = createMcpServer();
      expect(server, isNotNull);
    });
  });
}
