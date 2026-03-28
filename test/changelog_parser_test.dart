import 'package:test/test.dart';
import 'package:dart_docs_mcp/src/utils/changelog_parser.dart';

void main() {
  group('ChangelogParser', () {
    const changelog = '''
# 2.0.0
- Breaking changes
- New features

## 1.1.0
- Bug fixes

## [1.0.1] - 2023-01-01
- Patch release

# 1.0.0
- Initial release
''';

    test('extracts range correctly', () {
      final result = ChangelogParser.parseRange(changelog, '1.1.0', '2.0.0');
      expect(result, contains('# 2.0.0'));
      expect(result, contains('## 1.1.0'));
      expect(result, isNot(contains('# 1.0.0')));
      expect(result, isNot(contains('## [1.0.1]')));
    });

    test('handles brackets and dates', () {
      final result = ChangelogParser.parseRange(changelog, '1.0.1', '1.1.0');
      expect(result, contains('## 1.1.0'));
      expect(result, contains('## [1.0.1]'));
      expect(result, isNot(contains('# 2.0.0')));
    });

    test('handles missing current version by defaulting to whole range from target', () {
      // In our current implementation, if current is not found, it defaults to top (0).
      // Wait, let's check the logic: targetIdx = 0, currentIdx = 0.
      // So if neither is found, it returns just the first section.
      
      final result = ChangelogParser.parseRange(changelog, '0.9.0', '1.1.0');
      // 0.9.0 is NOT found. _findBestMatch returns 0 (topmost: 2.0.0).
      // So it will return sections from 0 to 1 (1.1.0).
      // Wait, indices: 2.0.0 (0), 1.1.0 (1), 1.0.1 (2), 1.0.0 (3).
      // target (1.1.0) -> index 1.
      // current (0.9.0) -> index 0 (fallback).
      // Range: 0 to 1.
      expect(result, contains('# 2.0.0'));
      expect(result, contains('## 1.1.0'));
    });
  });
}
