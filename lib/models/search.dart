/// 数据模型层：联网搜索相关结构（V1.3）
library;

/// 模型对"是否需要联网搜索"的判断结果
class SearchDecision {
  final bool needSearch;
  final String query;

  SearchDecision({required this.needSearch, required this.query});
}

/// 一条搜索结果（兼容 DeepSeek Search API 与自建服务）
class SearchResult {
  final String title;
  final String url;
  final String snippet;

  SearchResult({required this.title, required this.url, required this.snippet});
}
