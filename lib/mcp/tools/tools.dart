/// MCP tools for the server.
library;

import 'base_tool.dart';
import 'get_api_surface_tool.dart';
import 'get_package_docs_tool.dart';
import 'cross_reference_tool.dart';
import 'get_type_hierarchy_tool.dart';
import 'get_changelog_tool.dart';
import 'search_package_code_tool.dart';

export 'base_tool.dart';
export 'get_api_surface_tool.dart';
export 'get_package_docs_tool.dart';
export 'cross_reference_tool.dart';
export 'get_type_hierarchy_tool.dart';
export 'get_changelog_tool.dart';
export 'search_package_code_tool.dart';

/// Creates all available tools.
List<BaseTool> createAllTools() => [
  GetPackageDocsTool(),
  GetApiSurfaceTool(),
  GetTypeHierarchyTool(),
  CrossReferenceTool(),
  SearchPackageCodeTool(),
  GetChangelogTool(),
];