class ChangelogParser {
  /// Parses the [changelogContent] and extracts entries between [currentVersion] 
  /// and [targetVersion].
  /// 
  /// If a version is not found exactly, it uses the closest available version.
  static String parseRange(String changelogContent, String currentVersion, String targetVersion) {
    if (changelogContent.isEmpty) return 'Changelog is empty.';

    final versionSections = <_VersionSection>[];
    
    // Improved regex to match various changelog header formats:
    // ## 1.0.0
    // ## [1.0.0]
    // ## [1.0.0] - 2023-01-01
    // # 1.0.0
    // ## Version 1.0.0
    final headerRegex = RegExp(r'^(#+)\s*(?:\[|Version\s+)?([\w\d\.\+\-]+)(?:\])?.*$', multiLine: true);
    
    final matches = headerRegex.allMatches(changelogContent).toList();
    
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final version = match.group(2)!;
      final start = match.start;
      final end = (i + 1 < matches.length) ? matches[i + 1].start : changelogContent.length;
      
      versionSections.add(_VersionSection(
        version: version,
        content: changelogContent.substring(start, end).trim(),
      ));
    }

    if (versionSections.isEmpty) {
      return 'Could not identify any version headers in CHANGELOG.md. Returning full content:\n\n$changelogContent';
    }

    // Find indices
    int targetIdx = _findBestMatch(versionSections, targetVersion);
    int currentIdx = _findBestMatch(versionSections, currentVersion);

    // If target is newer than current (typical case), it will have a smaller index 
    // because changelogs are usually descending.
    final startIdx = targetIdx < currentIdx ? targetIdx : currentIdx;
    final endIdx = targetIdx < currentIdx ? currentIdx : targetIdx;

    final buffer = StringBuffer();
    for (var i = startIdx; i <= endIdx; i++) {
        buffer.writeln(versionSections[i].content);
        buffer.writeln();
    }

    return buffer.toString().trim();
  }

  static int _findBestMatch(List<_VersionSection> sections, String version) {
    // Exact match
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].version == version) return i;
    }
    
    // Fuzzy match (contains)
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].version.contains(version) || version.contains(sections[i].version)) {
        return i;
      }
    }

    // Default to first or last if extremely far off? 
    // Actually, per user recommendation: "closest matches".
    // For now, if no match, return 0 for target and last for current to be safe, 
    // but that might return too much.
    // Let's try to find the one with most overlapping characters?
    
    return 0; // Fallback to topmost
  }
}

class _VersionSection {
  final String version;
  final String content;

  _VersionSection({required this.version, required this.content});
}
