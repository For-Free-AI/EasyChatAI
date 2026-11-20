import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/conversation.dart';

/// v1.8.1：会话数据备份服务（v1.8.0 引入，本版优化导出/导入）
/// - 导出：用系统文件管理器（Android SAF / ACTION_CREATE_DOCUMENT）让用户自选位置保存 JSON
/// - 导入：选一个此前导出的 JSON 文件，解析后合并回现有会话（按 id 去重）
///
/// 不上传任何服务器，全程只在设备本地文件与 App 之间流转。
class BackupService {
  /// 导出文件名的固定前缀，便于用户识别
  static const String fileNamePrefix = 'EasyChatAI_backup';

  /// 备份 JSON 的顶层结构版本，便于将来格式升级时兼容
  static const int formatVersion = 1;

  /// 把会话列表序列化为带版本信息的 JSON 字符串
  static String encode(List<Conversation> conversations) {
    final payload = <String, dynamic>{
      'app': 'EasyChatAI',
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'conversations': conversations.map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 解析备份 JSON。返回会话列表；格式非法返回空列表。
  /// 兼容两种结构：① 本版带版本包装的对象；② 直接的会话数组（宽松兼容）。
  static List<Conversation> decode(String content) {
    try {
      final decoded = jsonDecode(content);
      List<dynamic> raw;
      if (decoded is Map<String, dynamic>) {
        raw = decoded['conversations'] as List<dynamic>? ?? [];
      } else if (decoded is List<dynamic>) {
        raw = decoded;
      } else {
        return [];
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map((e) => Conversation.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// v1.8.1 导出：调系统文件管理器让用户自选保存位置。
  /// Android/iOS 下 file_picker 的 saveFile 需要 bytes，由平台把字节写到用户选的位置。
  /// [fileName] 可指定默认文件名（单条对话导出时传入对话标题）。
  /// 返回用户选中的路径（非 null 即视为保存成功）；用户取消返回 null。
  static Future<String?> saveConversations(
    List<Conversation> conversations, {
    String? fileName,
  }) async {
    if (conversations.isEmpty) return null;
    final json = encode(conversations);
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final name = fileName ?? '${fileNamePrefix}_$stamp.json';
    try {
      return await FilePicker.platform.saveFile(
        dialogTitle: '保存对话备份',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: utf8.encode(json),
      );
    } catch (_) {
      return null;
    }
  }

  /// v1.8.1 导入：弹出系统文件选择器，读取并解析 JSON。
  /// 关键修复：不再用 allowedExtensions 过滤（部分手机会把备份改名/无后缀导致选不到），
  /// 改用 FileType.any 并优先读取 bytes（绕开 Android content:// 路径读取失败）。
  /// v1.8.2：分级校验导入格式——区分「不是 JSON / 没有对话数据 / 条目无效」，
  /// 单条解析失败只跳过该条，不影响其余对话导入。
  static Future<ImportResult> pickAndDecode() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
    } catch (_) {
      return ImportResult.error('无法打开文件选择器');
    }
    if (result == null || result.files.isEmpty) {
      return ImportResult.cancelled();
    }
    final file = result.files.single;
    String content;
    try {
      final bytes = file.bytes;
      if (bytes != null) {
        content = utf8.decode(bytes, allowMalformed: true);
      } else if (file.path != null) {
        // 兜底：个别平台未返回 bytes 时读路径
        content = await File(file.path!).readAsString();
      } else {
        return ImportResult.error('读取文件失败');
      }
    } catch (_) {
      return ImportResult.error('读取文件失败');
    }
    return classifyAndParse(content);
  }

  /// v1.8.2：把文本内容解析为会话列表，并给出具体的格式错误信息。
  /// 解析流程：① 必须是合法 JSON；② 必须能取到会话数组（带版本包装或裸数组均可）；
  /// ③ 单条对话解析失败只跳过；④ 全部无效时报错。
  static ImportResult classifyAndParse(String content) {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      return ImportResult.error('不是有效的 JSON 备份文件');
    }
    List<dynamic> raw;
    if (decoded is Map<String, dynamic>) {
      if (!decoded.containsKey('conversations')) {
        return ImportResult.error('文件中未找到对话数据，请选择 EasyChatAI 导出的备份');
      }
      raw = decoded['conversations'] as List<dynamic>? ?? [];
    } else if (decoded is List<dynamic>) {
      raw = decoded;
    } else {
      return ImportResult.error('文件中未找到对话数据，请选择 EasyChatAI 导出的备份');
    }
    if (raw.isEmpty) {
      return ImportResult.error('备份文件里没有对话（空备份）');
    }
    final conversations = <Conversation>[];
    for (final item in raw) {
      try {
        if (item is Map<String, dynamic>) {
          conversations.add(Conversation.fromJson(item));
        } else if (item is Map) {
          conversations.add(
            Conversation.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      } catch (_) {
        // 单条格式异常：跳过，不影响其余对话
      }
    }
    if (conversations.isEmpty) {
      return ImportResult.error('备份中没有可识别的对话数据');
    }
    return ImportResult.success(conversations);
  }

  /// 合并两组会话：以 id 为准去重，existing 中已有 id 的保留原样，
  /// incoming 中新的 id 追加进来。返回合并后的列表（incoming 在前，近期优先）。
  static List<Conversation> merge(
    List<Conversation> existing,
    List<Conversation> incoming,
  ) {
    final existingIds = existing.map((c) => c.id).toSet();
    final toAdd = incoming.where((c) => !existingIds.contains(c.id)).toList();
    return [...toAdd, ...existing];
  }
}

/// v1.8.1：导入结果——区分「用户取消 / 格式错误 / 成功」，
/// 让 UI 能给出明确提示，而不是像旧版那样静默失败。
class ImportResult {
  /// cancelled：用户取消选择；error：读取或格式错误；success：解析成功
  final ImportStatus status;
  final List<Conversation> conversations;
  final String? error;

  /// 实际新增的会话条数（由 provider 合并后回填；解析成功时默认等于解析条数）
  final int added;

  ImportResult._(this.status, this.conversations, this.error, this.added);

  factory ImportResult.cancelled() =>
      ImportResult._(ImportStatus.cancelled, const [], null, 0);
  factory ImportResult.error(String message) =>
      ImportResult._(ImportStatus.error, const [], message, 0);
  factory ImportResult.success(List<Conversation> list, {int? added}) =>
      ImportResult._(ImportStatus.success, list, null, added ?? list.length);
}

enum ImportStatus { cancelled, error, success }
