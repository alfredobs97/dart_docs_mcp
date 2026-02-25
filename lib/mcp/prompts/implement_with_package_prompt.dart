import 'package:mcp_dart/mcp_dart.dart';

import 'base_prompt.dart';

class ImplementWithPackagePrompt extends BasePrompt {
  @override
  String get name => 'implement-with-package';

  @override
  String get description =>
      'A prompt to help an AI agent implement a specific task using a Dart package by first reading its documentation.';

  @override
  Map<String, PromptArgumentDefinition>? get argsSchema => {
    'package_name': PromptArgumentDefinition(
      description: 'The exact name of the Dart package (e.g., path, http)',
      required: true,
    ),
    'task': PromptArgumentDefinition(
      description: 'The specific task or feature you want to implement using this package',
      required: true,
    ),
  };

  @override
  GetPromptResult getPrompt(Map<String, dynamic>? args, RequestHandlerExtra? extra) {
    final packageName = args?['package_name'] as String?;
    final task = args?['task'] as String?;

    if (packageName == null || packageName.isEmpty) {
      throw Exception('package_name is required');
    }
    if (task == null || task.isEmpty) {
      throw Exception('task is required');
    }

    return GetPromptResult(
      description: 'Implementation guide using package context',
      messages: [
        PromptMessage(
          role: PromptMessageRole.user,
          content: TextContent(
            text:
                'I need to implement the following task in my Dart/Flutter project:\n'
                '<task>\n$task\n</task>\n\n'
                'I want to use the `$packageName` package for this. '
                'Please use the `get_package_docs` tool to retrieve the complete README and example directory context for this package from pub.dev. '
                'After analyzing the official documentation and examples, provide a step-by-step implementation guide and the code needed to accomplish my task using best practices.',
          ),
        ),
      ],
    );
  }
}
