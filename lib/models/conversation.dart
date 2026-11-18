import 'message.dart';

/// 数据模型层：一次会话（对话）
/// V1.1 新增：每个会话各自记住所选模型、思考开关、自动命名状态
/// V1.3 新增：会话级联网搜索开关 enableSearch
class Conversation {
  String id;
  String title;
  List<ChatMessage> messages;
  DateTime updatedAt;

  /// 该会话使用的模型；为空表示跟随全局默认模型
  String model;

  /// 该会话的思考开关（所有模型都显示，用户自行判断）
  bool enableThinking;

  /// V1.3：该会话的联网搜索开关
  bool enableSearch;

  /// 是否已经触发过"首轮自动命名"（防止重复请求）
  bool namingTriggered;

  /// 是否允许用户手动改标题
  /// 规则：首轮回答完成（含自动命名流程结束）后才解锁
  bool canRename;

  Conversation({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    String? model,
    bool? enableThinking,
    bool? enableSearch,
    bool? namingTriggered,
    bool? canRename,
  })  : messages = messages ?? <ChatMessage>[],
        updatedAt = updatedAt ?? DateTime.now(),
        model = model ?? '',
        enableThinking = enableThinking ?? false,
        enableSearch = enableSearch ?? false,
        namingTriggered = namingTriggered ?? false,
        // 兼容旧数据：已有消息的会话默认允许改名
        canRename = canRename ?? (messages != null && messages.isNotEmpty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'model': model,
        'enableThinking': enableThinking,
        'enableSearch': enableSearch,
        'namingTriggered': namingTriggered,
        'canRename': canRename,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List<dynamic>? ?? [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? '新对话',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: msgs,
      model: json['model'] as String? ?? '',
      enableThinking: json['enableThinking'] as bool? ?? false,
      enableSearch: json['enableSearch'] as bool? ?? false,
      namingTriggered: json['namingTriggered'] as bool? ?? false,
      // 兼容：老会话按是否有消息判断；新会话按 stored 值
      canRename: json['canRename'] as bool? ?? msgs.isNotEmpty,
    );
  }
}
