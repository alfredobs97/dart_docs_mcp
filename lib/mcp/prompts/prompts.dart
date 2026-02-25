/// MCP prompts for the server.
library;

import 'base_prompt.dart';
import 'implement_with_package_prompt.dart';
import 'review_code_with_package_prompt.dart';

export 'base_prompt.dart';
export 'implement_with_package_prompt.dart';
export 'review_code_with_package_prompt.dart';

/// Creates all available prompts.
List<BasePrompt> createAllPrompts() => [
  ImplementWithPackagePrompt(),
  ReviewCodeWithPackagePrompt(),
];
