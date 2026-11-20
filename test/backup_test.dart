// v1.8.0 · A1 单元测试（续）
// 覆盖备份导出/导入的纯逻辑：JSON 编解码往返、按 id 去重合并、非法格式容错。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:agnes_chat/models/conversation.dart';
import 'package:agnes_chat/models/message.dart';
import 'package:agnes_chat/services/backup_service.dart';

void main() {
  group('BackupService', () {
    Conversation makeConv(String id, String title) => Conversation(
      id: id,
      title: title,
      messages: [ChatMessage(role: 'user', content: '内容-$id')],
    );

    test('encode/decode 往返保留全部会话与消息', () {
      final convs = [makeConv('a', '会话A'), makeConv('b', '会话B')];
      final json = BackupService.encode(convs);
      final restored = BackupService.decode(json);
      expect(restored.length, 2);
      expect(restored[0].id, 'a');
      expect(restored[0].title, '会话A');
      expect(restored[0].messages[0].content, '内容-a');
      expect(restored[1].id, 'b');
    });

    test('encode 输出含版本与导出时间元信息', () {
      final json = BackupService.encode([makeConv('x', 'X')]);
      expect(json, contains('"app": "EasyChatAI"'));
      expect(json, contains('"version": ${BackupService.formatVersion}'));
      expect(json, contains('"exportedAt"'));
    });

    test('decode 兼容直接的会话数组（宽松格式）', () {
      final raw = jsonEncode([makeConv('z', 'Z').toJson()]);
      final restored = BackupService.decode(raw);
      expect(restored.length, 1);
      expect(restored[0].id, 'z');
    });

    test('decode 对非法 JSON 返回空列表而不抛异常', () {
      expect(BackupService.decode('not json'), isEmpty);
      expect(BackupService.decode('{}'), isEmpty);
      expect(BackupService.decode('{"conversations":"wrong type"}'), isEmpty);
    });

    // v1.8.2：导入格式分级校验
    test('classifyAndParse 区分非法 JSON / 无对话数据 / 条目无效', () {
      // ① 不是 JSON
      final bad = BackupService.classifyAndParse('这不是JSON');
      expect(bad.status, ImportStatus.error);
      expect(bad.error, contains('JSON'));

      // ② 合法 JSON 但没有对话数据
      final empty = BackupService.classifyAndParse('{"app":"其他软件"}');
      expect(empty.status, ImportStatus.error);
      expect(empty.error, contains('未找到对话数据'));

      // ③ 空备份
      final blank = BackupService.classifyAndParse(
        '{"app":"EasyChatAI","conversations":[]}',
      );
      expect(blank.status, ImportStatus.error);
      expect(blank.error, contains('空备份'));

      // ④ 正常备份解析成功
      final ok = BackupService.classifyAndParse(
        BackupService.encode([makeConv('a', 'A')]),
      );
      expect(ok.status, ImportStatus.success);
      expect(ok.conversations.length, 1);

      // ⑤ 裸数组也兼容
      final bare = BackupService.classifyAndParse(
        jsonEncode([makeConv('b', 'B').toJson()]),
      );
      expect(bare.status, ImportStatus.success);
      expect(bare.conversations.first.id, 'b');

      // ⑥ 混入无效条目：跳过非法条目，保留有效对话
      //    （{'id':'d'} 只有 id，走旧数据兼容默认值，视为有效）
      final mixed = BackupService.classifyAndParse(
        jsonEncode([
          makeConv('c', 'C').toJson(),
          '不是对象的条目',
          {'id': 'd'},
        ]),
      );
      expect(mixed.status, ImportStatus.success);
      expect(mixed.conversations.map((c) => c.id), ['c', 'd']);
    });

    test('merge 按 id 去重：新增的加入，已存在的跳过', () {
      final existing = [makeConv('a', 'A'), makeConv('b', 'B')];
      final incoming = [
        makeConv('b', 'B新版'), // 已存在 → 跳过（保留原样）
        makeConv('c', 'C'), // 新 → 加入
      ];
      final merged = BackupService.merge(existing, incoming);
      expect(merged.length, 3);
      expect(merged.map((c) => c.id), containsAll(['a', 'b', 'c']));
      // b 保留的是 existing 里的原对象
      expect(merged.firstWhere((c) => c.id == 'b').title, 'B');
    });

    test('merge 全重复时不新增', () {
      final existing = [makeConv('a', 'A')];
      final merged = BackupService.merge(existing, [makeConv('a', 'A2')]);
      expect(merged.length, 1);
    });

    // v1.8.1：导入结果状态区分（取消 / 错误 / 成功）
    test('ImportResult.cancelled 状态正确且无错误文案', () {
      final r = ImportResult.cancelled();
      expect(r.status, ImportStatus.cancelled);
      expect(r.error, isNull);
      expect(r.added, 0);
    });

    test('ImportResult.error 携带错误文案，状态为 error', () {
      final r = ImportResult.error('文件格式不正确，未找到对话数据');
      expect(r.status, ImportStatus.error);
      expect(r.error, contains('文件格式不正确'));
    });

    test('ImportResult.success 默认 added 等于解析条数，可覆盖', () {
      final list = [makeConv('a', 'A'), makeConv('b', 'B')];
      final r = ImportResult.success(list);
      expect(r.status, ImportStatus.success);
      expect(r.added, 2);
      // 合并后实际新增可能少于解析条数，provider 会覆盖 added
      final r2 = ImportResult.success(list, added: 1);
      expect(r2.added, 1);
    });

    test('单条导出 JSON 往返：仅含该会话', () {
      final one = makeConv('solo', '单独对话');
      final restored = BackupService.decode(BackupService.encode([one]));
      expect(restored.length, 1);
      expect(restored[0].title, '单独对话');
    });
  });
}
