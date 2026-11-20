/// 数据模型层：一条聊天消息
/// role 取值：system / user / assistant（兼容 OpenAI 消息格式）
class ChatMessage {
  final String role;
  // 流式输出时需要逐段追加内容，故 content 设为可变
  String content;

  /// V1.3：本条助手回复是否触发过联网搜索
  bool searched;

  /// V1.3：本轮 token 用量（null 表示服务端未返回该字段）
  int? promptTokens;
  int? completionTokens;
  int? totalTokens;

  /// V1.4：思考/思维链文本（流式逐段追加）
  String reasoning;

  /// V1.4：本轮是否收到了「可读的思考文本」
  /// true  → 形态一：思维链可展开/收起
  /// false + thinkingEnabled=true → 形态二：仅状态提示，不可展开
  bool reasoningSupported;

  /// V1.4：本轮发送时用户是否开启了「思考：开」
  bool thinkingEnabled;

  ChatMessage({
    required this.role,
    required this.content,
    this.searched = false,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.reasoning = '',
    this.reasoningSupported = false,
    this.thinkingEnabled = false,
  });

  /// 转 JSON：用于本地持久化（含思考链与用量等扩展字段）
  /// 注意：发给大模型的 history 在网络层只取 role/content，不回传思考过程
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'searched': searched,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
    'reasoning': reasoning,
    'reasoningSupported': reasoningSupported,
    'thinkingEnabled': thinkingEnabled,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      searched: json['searched'] as bool? ?? false,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      totalTokens: json['totalTokens'] as int?,
      reasoning: json['reasoning'] as String? ?? '',
      reasoningSupported: json['reasoningSupported'] as bool? ?? false,
      thinkingEnabled: json['thinkingEnabled'] as bool? ?? false,
    );
  }
}
