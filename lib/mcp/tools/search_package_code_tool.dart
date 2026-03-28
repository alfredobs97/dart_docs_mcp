import 'package:mcp_dart/mcp_dart.dart';
import '../../src/pub_service_archive.dart';
import 'base_tool.dart';

class SearchPackageCodeTool extends BaseTool {
  final ArchivePubService _service;

  SearchPackageCodeTool({ArchivePubService? service})
      : _service = service ?? ArchivePubService();

  @override
  String get name => 'search_package_code';

  @override
  String get description =>
      'Performs a case-insensitive keyword or regex search across the internal '
      '`lib/` source files of a pub.dev package. '
      'Returns file paths, 1-based line numbers, and a ±3-line context snippet '
      'for each match. Generated files (e.g. *.g.dart, *.freezed.dart) are '
      'excluded. Results are capped at 15 matches. '
      'Use this to inspect private implementation details that are not covered '
      'by the public API surface or README.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
        properties: {
          'package_name': JsonSchema.string(
            description:
                'The exact name of the Dart or Flutter package on pub.dev '
                '(e.g., http, riverpod).',
          ),
          'search_query': JsonSchema.string(
            description:
                'The keyword or regex pattern to search for across the '
                'package\'s lib/ Dart source files (case-insensitive).',
          ),
        },
        required: ['package_name', 'search_query'],
      );

  @override
  ToolAnnotations get annotations => ToolAnnotations(readOnlyHint: true);

  @override
  Future<CallToolResult> execute(
      Map<String, dynamic> args, RequestHandlerExtra? extra) async {
    final packageName = args['package_name']?.toString();
    final searchQuery = args['search_query']?.toString();

    if (packageName == null || packageName.isEmpty) {
      throw Exception('package_name is required');
    }
    if (searchQuery == null || searchQuery.isEmpty) {
      throw Exception('search_query is required');
    }

    try {
      final matches =
          await _service.searchPackageCode(packageName, searchQuery);

      if (matches.isEmpty) {
        return CallToolResult.fromContent([
          TextContent(
            text: 'No matches found for "$searchQuery" in $packageName/lib/.',
          ),
        ]);
      }

      final buffer = StringBuffer();
      buffer.writeln(
          '# Search results for "$searchQuery" in $packageName/lib/');
      buffer.writeln(
          '${matches.length} match${matches.length == 1 ? '' : 'es'} found'
          '${matches.length == 15 ? ' (limit reached — results may be truncated)' : ''}:\n');

      for (final match in matches) {
        buffer.writeln('## ${match.filePath}:${match.lineNumber}');
        buffer.writeln('```');
        buffer.writeln(match.snippet);
        buffer.writeln('```\n');
      }

      return CallToolResult.fromContent([TextContent(text: buffer.toString())]);
    } catch (e) {
      return CallToolResult.fromContent([
        TextContent(text: 'Error searching $packageName: $e'),
      ]);
    }
  }
}
