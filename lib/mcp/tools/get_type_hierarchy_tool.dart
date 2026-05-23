import 'package:mcp_dart/mcp_dart.dart';

import '../../src/type_hierarchy_service.dart';
import 'base_tool.dart';

class GetTypeHierarchyTool extends BaseTool {
  final TypeHierarchyService? _service;

  GetTypeHierarchyTool({TypeHierarchyService? service}) : _service = service;

  @override
  String get name => 'get_type_hierarchy';

  @override
  String get description =>
      'Reconstruct the inheritance and implementation tree of a remote Dart class '
      '(handles sealed, base, interface, and mixin modifiers). '
      'Use this to discover all subclasses, implementers, and mixin consumers of a type '
      'before writing exhaustive switch expressions or instantiating concrete variants. '
      'Especially critical for sealed classes in Dart 3, where exhaustive pattern matching '
      'requires knowing every direct subclass at compile time.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'package_name': JsonSchema.string(
        description: 'The exact pub.dev package name (e.g., "riverpod", "characters").',
      ),
      'type_name': JsonSchema.string(
        description:
            'The exact class, mixin, or interface name to inspect '
            '(e.g., "Part", "AsyncValue", "RouteBase").',
      ),
      'namespace': JsonSchema.string(
        description:
            'Optional. The library namespace used in the Dartdoc URL '
            '(e.g., "characters" or "dart-async"). '
            'If omitted, the tool tries common patterns automatically.',
      ),
    },
    required: ['package_name', 'type_name'],
  );

  @override
  ToolAnnotations get annotations => ToolAnnotations(
        title: 'Get Type Hierarchy',
        readOnlyHint: true,
        idempotentHint: true,
        openWorldHint: true,
      );

  @override
  Future<CallToolResult> execute(Map<String, dynamic> args, RequestHandlerExtra? extra) async {
    final packageName = args['package_name']?.toString();
    if (packageName == null || packageName.isEmpty) {
      throw Exception('package_name is required');
    }

    final typeName = args['type_name']?.toString();
    if (typeName == null || typeName.isEmpty) {
      throw Exception('type_name is required');
    }

    final namespace = args['namespace']?.toString();

    final service = _service ?? TypeHierarchyService();
    final result = await service.getTypeHierarchy(packageName, typeName, namespace: namespace);

    return CallToolResult.fromContent([TextContent(text: result)]);
  }
}
