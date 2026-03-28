import 'package:mcp_dart/mcp_dart.dart';
import '../../src/pub_service.dart';
import '../../src/pub_service_archive.dart';
import '../../src/pub_service_github.dart';
import '../../src/utils/changelog_parser.dart';
import 'base_tool.dart';

class GetChangelogTool extends BaseTool {
  final PubService? _pubService;

  GetChangelogTool({PubService? pubService}) : _pubService = pubService;

  @override
  String get name => 'get_changelog';

  @override
  String get description =>
      'Fetch the CHANGELOG.md for a Dart/Flutter package '
      'and return the specific entries between current and target versions. '
      'Use this to understand breaking changes and migration steps.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'package_name': JsonSchema.string(
        description: 'The exact name of the Dart or Flutter package (e.g., http, riverpod)',
      ),
      'current_version': JsonSchema.string(
        description: 'The version of the package currently in use (e.g., 1.0.0)',
      ),
      'target_version': JsonSchema.string(
        description: 'The version you want to update to (e.g., 2.1.0)',
      ),
      'source': JsonSchema.string(
        description: 'The source to fetch from: "archive" (default - recommended) or "github".',
        enumValues: ['archive', 'github'],
      ),
    },
    required: ['package_name', 'current_version', 'target_version'],
  );

  @override
  Future<CallToolResult> execute(Map<String, dynamic> args, RequestHandlerExtra? extra) async {
    try {
      final packageName = args['package_name']?.toString();
      final currentVersion = args['current_version']?.toString();
      final targetVersion = args['target_version']?.toString();

      if (packageName == null || packageName.isEmpty) {
        throw Exception('package_name is required');
      }
      if (currentVersion == null || currentVersion.isEmpty) {
        throw Exception('current_version is required');
      }
      if (targetVersion == null || targetVersion.isEmpty) {
        throw Exception('target_version is required');
      }

      final source = args['source']?.toString() ?? 'archive';

      final PubService service =
          _pubService ?? (source == 'github' ? GithubPubService() : ArchivePubService());

      final rawChangelog = await service.getChangelog(packageName);

      if (rawChangelog == null || rawChangelog.isEmpty) {
        return CallToolResult(
          content: [TextContent(text: 'Could not find CHANGELOG.md for package $packageName.')],
          isError: true,
        );
      }

      final filteredChangelog = ChangelogParser.parseRange(
        rawChangelog,
        currentVersion,
        targetVersion,
      );

      return CallToolResult.fromContent([TextContent(text: filteredChangelog)]);
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }
}
