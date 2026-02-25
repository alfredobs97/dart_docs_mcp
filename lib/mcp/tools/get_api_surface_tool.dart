import 'package:mcp_dart/mcp_dart.dart';

import '../../src/api_surface_service.dart';
import 'base_tool.dart';

/// MCP tool that extracts the public API surface of a Dart/Flutter package
/// using the Dartdoc `index.json` hosted by pub.dev.
///
/// Rather than reading large source files, this tool fetches the lightweight
/// `index.json` (generated at publish time by `dartdoc`) which lists every
/// public class, enum, mixin, method, property, and function — with all
/// private symbols already stripped out. It then synthesizes a concise
/// "virtual Dart header" showing public symbols organised by their container.
///
/// This dramatically reduces the tokens needed for an LLM to understand a
/// package's public contract compared to reading raw implementation files.
class GetApiSurfaceTool extends BaseTool {
  final ApiSurfaceService? _service;

  GetApiSurfaceTool({ApiSurfaceService? service}) : _service = service;

  @override
  String get name => 'get_api_surface';

  @override
  String get description =>
      'Fetches the public API surface of a Dart or Flutter package from pub.dev '
      'using the pre-rendered Dartdoc index.json. Returns a concise listing of '
      'all public classes, enums, mixins, methods, constructors, and top-level '
      'functions — with all private symbols stripped. Use this to quickly '
      'understand a package\'s public API contract without reading full source files. '
      'Optionally filter to a specific class or enum by name.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'package_name': JsonSchema.string(
        description:
            'The exact name of the Dart or Flutter package on pub.dev (e.g., http, riverpod)',
      ),
      'class_name': JsonSchema.string(
        description:
            'Optional. If provided, output is filtered to only show the '
            'members of this specific class or enum (case-insensitive).',
      ),
    },
    required: ['package_name'],
  );

  @override
  ToolAnnotations get annotations => ToolAnnotations(readOnlyHint: true, idempotentHint: true);

  @override
  Future<CallToolResult> execute(Map<String, dynamic> args, RequestHandlerExtra? extra) async {
    final packageName = args['package_name']?.toString();
    if (packageName == null || packageName.isEmpty) {
      throw Exception('package_name is required');
    }

    final className = args['class_name']?.toString();

    final service = _service ?? ApiSurfaceService();
    final surface = await service.getApiSurface(packageName, className: className);

    return CallToolResult.fromContent([TextContent(text: surface)]);
  }
}
