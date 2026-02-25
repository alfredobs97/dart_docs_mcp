import 'package:mcp_dart/mcp_dart.dart';

import 'base_resource.dart';

/// A resource providing a quick reference to popular Dart/Flutter packages.
class PopularPackagesResource extends BaseResource {
  @override
  String get name => 'popular-dart-packages';

  @override
  Uri get uri => Uri.parse('pub://popular_packages');

  @override
  String get mimeType => 'text/markdown';

  @override
  String get description =>
      'A quick reference guide to some of the most popular and essential Dart and Flutter packages.';

  @override
  ReadResourceResult read(Uri requestUri, RequestHandlerExtra? extra) {
    if (requestUri != uri) {
      throw Exception('Invalid URI path: \${requestUri.path}');
    }

    const markdownContent = '''# Popular Dart and Flutter Packages Quick Reference

## State Management
- **riverpod**: A reactive caching and data-binding framework.
- **provider**: A wrapper around InheritedWidget to make them easier to use and more reusable.
- **flutter_bloc**: Predictable state management library that helps implement the BLoC design pattern.
- **get**: Extra-light and powerful state management, dependency injection, and route management.

## Network & Serialization
- **http**: A composable, cross-platform, multi-platform, Future-based API for making HTTP requests.
- **dio**: A powerful HTTP client for Dart/Flutter, which supports interceptors, global configuration, FormData, request cancellation, file downloading, timeout, etc.
- **json_annotation** / **json_serializable**: Classes and helper functions that support JSON code generation.
- **freezed**: Code generation for immutable classes that has a simple syntax/API without compromising on the features.

## Storage
- **shared_preferences**: Wraps specific platform-specific persistent storage for simple data (NSUserDefaults on iOS and macOS, SharedPreferences on Android, etc.).
- **sqflite**: SQLite plugin for Flutter. Supports iOS, Android and MacOS.
- **hive**: Lightweight and blazing fast key-value database written in pure Dart. Strongly encrypted using AES-256.

## Utilities
- **path**: A string-based path manipulation library.
- **uuid**: RFC4122 (v1, v4, v5) UUID Generator and Parser for all Dart platforms.
- **intl**: Contains code to deal with internationalized/localized messages, date and number formatting and parsing, bi-directional text, and other internationalization issues.

You can use the `get_package_docs` tool on any of these to see their details!
''';

    return ReadResourceResult(
      contents: [
        TextResourceContents(uri: requestUri.toString(), mimeType: mimeType, text: markdownContent),
      ],
    );
  }
}
