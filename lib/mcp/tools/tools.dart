/// MCP tools for the server.
library;

import 'base_tool.dart';
import 'get_package_docs_tool.dart';
import 'get_type_hierarchy_tool.dart';

export 'base_tool.dart';
export 'get_package_docs_tool.dart';
export 'get_type_hierarchy_tool.dart';

/// Creates all available tools.
List<BaseTool> createAllTools() => [GetPackageDocsTool(), GetTypeHierarchyTool()];
