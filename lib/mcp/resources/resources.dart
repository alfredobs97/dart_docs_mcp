/// MCP resources for the server.
library;

import 'base_resource.dart';
import 'popular_packages_resource.dart';

export 'base_resource.dart';
export 'popular_packages_resource.dart';

/// Creates all available resources.
List<BaseResource> createAllResources() => [PopularPackagesResource()];
