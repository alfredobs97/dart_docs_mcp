import 'package:mcp_dart/mcp_dart.dart';
import '../../src/pub_service.dart';
import '../../src/pub_service_archive.dart';
import '../../src/pub_service_github.dart';
import 'base_tool.dart';

class GetPackageDocsTool extends BaseTool {
  final PubService? _pubService;

  GetPackageDocsTool({PubService? pubService}) : _pubService = pubService;

  @override
  String get name => 'get_package_docs';

  @override
  String get description =>
      'Fetch the README and example directory '
      'documentation for a Dart and/or Flutter package from pub.dev to provide context. '
      'Use this when you need documentation and examples for a pub.dev package dependency.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'package_name': JsonSchema.string(
        description: 'The exact name of the Dart or Flutter package (e.g., http, riverpod)',
      ),
      'source': JsonSchema.string(
        description: 'The source to fetch from: "archive" (default - recommended) or "github".',
        enumValues: ['archive', 'github'],
      ),
    },
    required: ['package_name'],
  );

  @override
  Future<CallToolResult> execute(Map<String, dynamic> args, RequestHandlerExtra? extra) async {
    final packageName = args['package_name']?.toString();
    if (packageName == null || packageName.isEmpty) {
      throw Exception('package_name is required');
    }

    final source = args['source']?.toString() ?? 'archive';

    final PubService service =
        _pubService ?? (source == 'github' ? GithubPubService() : ArchivePubService());

    final docs = await service.getPackageDocs(packageName);

    return CallToolResult.fromContent([TextContent(text: docs)]);
  }
}
