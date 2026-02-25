import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants/api_constants.dart';
import 'models/dartdoc_entry.dart';

/// Service that fetches and renders the public API surface of a Dart package
/// using pub.dev's pre-rendered Dartdoc assets.
class ApiSurfaceService {
  final http.Client _client;

  ApiSurfaceService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches and renders the public API surface for [packageName].
  Future<String> getApiSurface(String packageName, {String? className}) async {
    final buffer = StringBuffer();
    buffer.writeln('// Public API surface for package:$packageName');
    if (className != null) {
      buffer.writeln('// Filtered to: $className');
    }
    buffer.writeln('// Generated from pub.dev Dartdoc index.json');
    buffer.writeln('// NOTE: Signatures show symbol names and kinds only.');
    buffer.writeln();

    try {
      final version = await _fetchLatestVersion(packageName);
      final entries = await _fetchDartdocIndex(packageName, version);

      if (entries.isEmpty) {
        buffer.writeln('// No Dartdoc index found for $packageName $version.');
        buffer.writeln('// The package may not have documentation hosted on pub.dev.');
        return buffer.toString();
      }

      _renderApiSurface(buffer, entries, packageName, version, className: className);
    } catch (e) {
      buffer.writeln('// Error fetching API surface: $e');
    }

    return buffer.toString();
  }

  Future<String> _fetchLatestVersion(String packageName) async {
    final url = Uri.parse(ApiConstants.pubDevPackageUrl(packageName));
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch package info from pub.dev (HTTP ${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = json['latest'] as Map<String, dynamic>?;
    final version = latest?['version'] as String?;
    if (version == null || version.isEmpty) {
      throw Exception('Could not determine latest version for $packageName');
    }
    return version;
  }

  Future<List<DartdocEntry>> _fetchDartdocIndex(String packageName, String version) async {
    final url = Uri.parse(ApiConstants.pubDevDartdocIndexUrl(packageName, version));
    final response = await _client.get(url);

    if (response.statusCode == 404) {
      return [];
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Dartdoc index (HTTP ${response.statusCode})');
    }

    final jsonList = jsonDecode(response.body) as List<dynamic>;
    return jsonList.map((e) => DartdocEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _renderApiSurface(
    StringBuffer buffer,
    List<DartdocEntry> entries,
    String packageName,
    String version, {
    String? className,
  }) {
    buffer.writeln('// Package: $packageName v$version');
    buffer.writeln('// Total public symbols: ${entries.length}');
    buffer.writeln();

    // Top-level containers (classes, enums, etc.)
    // They are enclosed by a library (kind 9) or nothing.
    final containers = entries
        .where((e) => e.isContainer && (e.enclosedBy == null || e.enclosedBy!.kind == 9))
        .toList();

    final topLevelSymbols = entries.where((e) => e.isTopLevel).toList();

    if (className != null) {
      final matchedContainer = containers
          .where((e) => e.name.toLowerCase() == className.toLowerCase())
          .toList();

      if (matchedContainer.isEmpty) {
        buffer.writeln('// No public symbol named "$className" found in $packageName.');
        return;
      }

      for (final container in matchedContainer) {
        _writeContainer(buffer, container, entries);
        buffer.writeln();
      }
      return;
    }

    // Sort containers by name for readability
    containers.sort((a, b) => a.name.compareTo(b.name));

    for (final container in containers) {
      _writeContainer(buffer, container, entries);
      buffer.writeln();
    }

    if (topLevelSymbols.isNotEmpty) {
      buffer.writeln('// ─── Top-level symbols ───');
      for (final sym in topLevelSymbols) {
        _writeTopLevelEntry(buffer, sym);
      }
    }
  }

  void _writeContainer(StringBuffer buffer, DartdocEntry container, List<DartdocEntry> allEntries) {
    final members = allEntries
        .where(
          (e) =>
              e.enclosedBy != null &&
              e.enclosedBy!.name == container.name &&
              e.enclosedBy!.kind == container.kind,
        )
        .toList();

    String typeLabel = 'class';
    if (container.kind == 5) typeLabel = 'enum';
    if (container.kind == 11) typeLabel = 'mixin';
    if (container.kind == 6) typeLabel = 'extension';

    buffer.writeln('$typeLabel ${container.name} {');

    if (container.kind == 5) {
      _writeEnumValues(buffer, members);
    } else {
      _writeMembers(buffer, members, container.name);
    }

    buffer.writeln('}');
  }

  void _writeEnumValues(StringBuffer buffer, List<DartdocEntry> members) {
    final values = members.where((e) => e.kind == 4).toList(); // Constant for enum values
    for (final v in values) {
      buffer.writeln('  ${v.name},');
    }

    final methods = members.where((e) => e.kind == 10).toList();
    if (methods.isNotEmpty) {
      buffer.writeln();
      for (final m in methods) {
        buffer.writeln('  dynamic ${m.name}(...);');
      }
    }
  }

  void _writeMembers(StringBuffer buffer, List<DartdocEntry> members, String containerName) {
    final constructors = members.where((e) => e.kind == 2).toList();
    final properties = members.where((e) => e.kind == 8 || e.kind == 13).toList();
    final methods = members.where((e) => e.kind == 10 || e.kind == 12).toList();

    for (final c in constructors) {
      if (c.name == 'new' || c.name == containerName) {
        buffer.writeln('  $containerName(...);');
      } else {
        buffer.writeln('  $containerName.${c.name}(...);');
      }
    }

    if (properties.isNotEmpty) {
      if (constructors.isNotEmpty) buffer.writeln();
      for (final p in properties) {
        final label = p.kind == 13 ? 'set' : 'get';
        buffer.writeln('  dynamic $label ${p.name};');
      }
    }

    if (methods.isNotEmpty) {
      if (properties.isNotEmpty || constructors.isNotEmpty) buffer.writeln();
      for (final m in methods) {
        buffer.writeln('  dynamic ${m.name}(...);');
      }
    }
  }

  void _writeTopLevelEntry(StringBuffer buffer, DartdocEntry entry) {
    if (entry.kind == 15) {
      buffer.writeln('typedef ${entry.name} = dynamic Function(...);');
    } else if (entry.kind == 14) {
      buffer.writeln('dynamic get ${entry.name};');
    } else {
      buffer.writeln('dynamic ${entry.name}(...);');
    }
  }
}
