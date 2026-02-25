import 'package:mcp_dart/mcp_dart.dart';
import '../../src/github_search_service.dart';
import 'base_tool.dart';

class CrossReferenceTool extends BaseTool {
  final GithubSearchService _searchService;

  CrossReferenceTool({GithubSearchService? searchService})
    : _searchService = searchService ?? GithubSearchService(),
      super(
        name: 'cross_reference',
        description:
            'Maps a conceptual feature described in a package README to its actual implementation inside the repository .dart files.',
      );

  @override
  List<ToolProperty> get properties => [
    ToolProperty(
      name: 'package_name',
      description: 'The name of the Dart package (e.g., "google_generative_ai").',
      type: 'string',
      isRequired: true,
    ),
    ToolProperty(
      name: 'feature',
      description: 'The conceptual feature to cross-reference (e.g., "Function Calling").',
      type: 'string',
      isRequired: true,
    ),
  ];

  @override
  Future<CallToolResult> call(Map<String, dynamic> arguments) async {
    final packageName = arguments['package_name'] as String;
    final feature = arguments['feature'] as String;

    final result = await _searchService.crossReferenceFeature(
      packageName: packageName,
      feature: feature,
    );

    return CallToolResult(content: [TextContent(text: result)], isError: false);
  }
}
