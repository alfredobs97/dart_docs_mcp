import 'package:mcp_dart/mcp_dart.dart';
import '../../src/github_search_service.dart';
import 'base_tool.dart';

class CrossReferenceTool extends BaseTool {
  final GithubSearchService _searchService;

  CrossReferenceTool({GithubSearchService? searchService})
    : _searchService = searchService ?? GithubSearchService();

  @override
  String get name => 'cross_reference';

  @override
  String get description =>
      'Maps a conceptual feature described in a package README to its actual implementation inside the repository .dart files.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'package_name': JsonSchema.string(
        description: 'The name of the Dart package (e.g., "google_generative_ai").',
      ),
      'feature': JsonSchema.string(
        description: 'The conceptual feature to cross-reference (e.g., "Function Calling").',
      ),
    },
    required: ['package_name', 'feature'],
  );

  @override
  ToolAnnotations get annotations => ToolAnnotations(
        title: 'Cross-Reference Feature',
        readOnlyHint: true,
      );

  @override
  Future<CallToolResult> execute(Map<String, dynamic> args, RequestHandlerExtra? extra) async {
    final packageName = args['package_name']?.toString();
    final feature = args['feature']?.toString();

    if (packageName == null || feature == null) {
      throw Exception('package_name and feature are required');
    }

    final result = await _searchService.crossReferenceFeature(
      packageName: packageName,
      feature: feature,
    );

    return CallToolResult.fromContent([TextContent(text: result)]);
  }
}
