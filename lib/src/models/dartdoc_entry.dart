/// Represents a single entry in the Dartdoc-generated index.json.
///
/// pub.dev runs `dartdoc` when a package is published, which produces a
/// strictly typed JSON array containing the full public API taxonomy.
/// Each [DartdocEntry] maps to one public symbol (class, method, property, etc.)
class DartdocEntry {
  /// The unqualified symbol name, e.g. `generateContent`.
  final String name;

  /// The fully-qualified name, e.g. `google_generative_ai.GenerativeModel.generateContent`.
  final String qualifiedName;

  /// Relative documentation href within the Dartdoc site.
  final String href;

  /// The kind of symbol (integer code used by Dartdoc).
  ///
  /// Common values:
  /// - 2: Constructor
  /// - 3: Class
  /// - 4: Constant
  /// - 5: Enum
  /// - 6: Extension
  /// - 7: Function
  /// - 8: Getter / Property
  /// - 9: Library
  /// - 10: Method
  /// - 11: Mixin
  /// - 12: Operator
  /// - 13: Setter
  /// - 14: Top-level property
  /// - 15: Typedef
  /// - 16: Parameter / Field
  final int kind;

  /// The symbol that directly encloses this entry, if any.
  final DartdocEntryEnclosedBy? enclosedBy;

  const DartdocEntry({
    required this.name,
    required this.qualifiedName,
    required this.href,
    required this.kind,
    this.enclosedBy,
  });

  factory DartdocEntry.fromJson(Map<String, dynamic> json) {
    return DartdocEntry(
      name: json['name'] as String? ?? '',
      qualifiedName: json['qualifiedName'] as String? ?? '',
      href: json['href'] as String? ?? '',
      kind: json['kind'] as int? ?? 0,
      enclosedBy: json['enclosedBy'] != null
          ? DartdocEntryEnclosedBy.fromJson(json['enclosedBy'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Whether this entry is a container (class, enum, mixin, extension).
  bool get isContainer =>
      kind == 3 || // Class
      kind == 5 || // Enum
      kind == 6 || // Extension
      kind == 11; // Mixin

  /// Whether this entry is a member of a container.
  bool get isMember =>
      kind == 2 || // Constructor
      kind == 10 || // Method
      kind == 8 || // Property / Getter
      kind == 13 || // Setter
      kind == 12 || // Operator
      kind == 4; // Constant

  /// Whether this entry is a top-level symbol (not enclosed by a container).
  bool get isTopLevel =>
      (kind == 7 || // Function
          kind == 14 || // Top-level property
          kind == 15) && // Typedef
      (enclosedBy == null || enclosedBy!.kind == 9);
}

/// Represents the parent container of a [DartdocEntry].
class DartdocEntryEnclosedBy {
  final String name;
  final int kind;
  final String href;

  const DartdocEntryEnclosedBy({required this.name, required this.kind, required this.href});

  factory DartdocEntryEnclosedBy.fromJson(Map<String, dynamic> json) {
    return DartdocEntryEnclosedBy(
      name: json['name'] as String? ?? '',
      kind: json['kind'] as int? ?? 0,
      href: json['href'] as String? ?? '',
    );
  }
}
