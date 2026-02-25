class GithubRepoInfo {
  final String owner;
  final String repo;
  final String? pathPrefix;

  GithubRepoInfo({required this.owner, required this.repo, this.pathPrefix});
}
