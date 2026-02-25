import 'package:mcp_dart/mcp_dart.dart';

import 'base_prompt.dart';

class ReviewCodeWithPackagePrompt extends BasePrompt {
  @override
  String get name => 'review-code-with-package';

  @override
  String get description =>
      'A prompt to review existing code against the official documentation and examples of a Dart package.';

  @override
  Map<String, PromptArgumentDefinition>? get argsSchema => {
    'package_name': PromptArgumentDefinition(
      description: 'The exact name of the Dart package (e.g., path, http)',
      required: true,
    ),
    'code': PromptArgumentDefinition(
      description: 'The code snippet you want reviewed',
      required: true,
    ),
  };

  @override
  GetPromptResult getPrompt(Map<String, dynamic>? args, RequestHandlerExtra? extra) {
    final packageName = args?['package_name'] as String?;
    final code = args?['code'] as String?;

    if (packageName == null || packageName.isEmpty) {
      throw Exception('package_name is required');
    }
    if (code == null || code.isEmpty) {
      throw Exception('code is required');
    }

    return GetPromptResult(
      description: 'Request for code review based on package best practices',
      messages: [
        PromptMessage(
          role: PromptMessageRole.user,
          content: TextContent(
            text:
                'I have written the following code using the `$packageName` package:\n'
                '<code>\n$code\n</code>\n\n'
                'Please use the `get_package_docs` tool to retrieve the repository README and the example directory for this package. '
                'After analyzing the official patterns and examples, review my code. Point out any anti-patterns, potential bugs, '
                'or areas where I am not using the package idiomatically, and provide the corrected code.',
          ),
        ),
      ],
    );
  }
}
