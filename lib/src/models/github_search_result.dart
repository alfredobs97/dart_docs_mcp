class GithubSearchResult {
  final int totalCount;
  final bool incompleteResults;
  final List<GithubSearchItem> items;

  GithubSearchResult({
    required this.totalCount,
    required this.incompleteResults,
    required this.items,
  });

  factory GithubSearchResult.fromJson(Map<String, dynamic> json) {
    return GithubSearchResult(
      totalCount: json['total_count'] as int,
      incompleteResults: json['incomplete_results'] as bool,
      items: (json['items'] as List<dynamic>)
          .map((item) => GithubSearchItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GithubSearchItem {
  final String name;
  final String path;
  final String sha;
  final String url;
  final String gitUrl;
  final String htmlUrl;
  final GithubSearchResultRepository repository;
  final double score;

  GithubSearchItem({
    required this.name,
    required this.path,
    required this.sha,
    required this.url,
    required this.gitUrl,
    required this.htmlUrl,
    required this.repository,
    required this.score,
  });

  factory GithubSearchItem.fromJson(Map<String, dynamic> json) {
    return GithubSearchItem(
      name: json['name'] as String,
      path: json['path'] as String,
      sha: json['sha'] as String,
      url: json['url'] as String,
      gitUrl: json['git_url'] as String,
      htmlUrl: json['html_url'] as String,
      repository: GithubSearchResultRepository.fromJson(json['repository'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
    );
  }
}

class GithubSearchResultRepository {
  final int id;
  final String name;
  final String fullName;
  final bool private;
  final String htmlUrl;

  GithubSearchResultRepository({
    required this.id,
    required this.name,
    required this.fullName,
    required this.private,
    required this.htmlUrl,
  });

  factory GithubSearchResultRepository.fromJson(Map<String, dynamic> json) {
    return GithubSearchResultRepository(
      id: json['id'] as int,
      name: json['name'] as String,
      fullName: json['full_name'] as String,
      private: json['private'] as bool,
      htmlUrl: json['html_url'] as String,
    );
  }
}
