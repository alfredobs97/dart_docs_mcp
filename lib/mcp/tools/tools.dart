/// MCP tools for the server.
library;

import 'base_tool.dart';
import 'get_api_surface_tool.dart';
import 'get_package_docs_tool.dart';
import 'cross_reference_tool.dart';

export 'base_tool.dart';
export 'get_api_surface_tool.dart';
export 'get_package_docs_tool.dart';
export 'cross_reference_tool.dart';

/// Creates all available tools.
List<BaseTool> createAllTools() => [
  GetPackageDocsTool(),
  GetApiSurfaceTool(),
  CrossReferenceTool(),
];
