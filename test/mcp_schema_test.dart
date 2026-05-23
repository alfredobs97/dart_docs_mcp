import 'package:test/test.dart';
import 'package:dart_docs_mcp/mcp/mcp.dart';

void main() {
  group('MCP Tool Schema Validation', () {
    test('All registered tools must have a non-null title in annotations', () {
      // Access the internal tools list if possible, or use the server's registration logic.
      // Since we can't easily access the private registry, we can test the tools directly
      // from createAllTools().
      final tools = createAllTools();

      for (final tool in tools) {
        final annotations = tool.annotations;
        if (annotations != null) {
          expect(
            annotations.title,
            isNotNull,
            reason:
                'Tool "${tool.name}" has annotations but title is null. '
                'Gemini requires a string title in annotations.',
          );
        }
      }
    });

    test('Verify JSON serialization does not include null title', () {
      final tools = createAllTools();

      for (final tool in tools) {
        final annotations = tool.annotations;
        if (annotations != null) {
          final json = annotations.toJson();
          // Gemini fails if "title" is present but null.
          // Our fix was to provide a title, but we should also check if it's null.
          expect(
            json['title'],
            isA<String>(),
            reason: 'Tool "${tool.name}" JSON annotations["title"] must be a String.',
          );
        }
      }
    });
  });
}
