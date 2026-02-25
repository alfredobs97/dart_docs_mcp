class GithubContentNode {
  final String type;
  final String path;
  final String name;
  final String? downloadUrl;

  GithubContentNode({required this.type, required this.path, required this.name, this.downloadUrl});

  factory GithubContentNode.fromJson(Map<String, dynamic> json) {
    return GithubContentNode(
      type: json['type'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      downloadUrl: json['download_url'] as String?,
    );
  }

  bool get isFile => type == 'file';
  bool get isDirectory => type == 'dir';
}
