// v1.8.4：快捷提示词随机抽取测试
import 'package:flutter_test/flutter_test.dart';

import 'package:agnes_chat/config/prompt_presets.dart';

void main() {
  test('预设库包含足够多的条目', () {
    expect(kPromptPresets.length, greaterThanOrEqualTo(10));
  });

  test('pickPrompts 默认抽取 3 条且不重复', () {
    final picked = pickPrompts('conv-abc');
    expect(picked.length, 3);
    final texts = picked.map((p) => p.text).toSet();
    expect(texts.length, 3);
  });

  test('pickPrompts 对同一 seed 结果稳定', () {
    final a = pickPrompts('same-id').map((p) => p.text).toList();
    final b = pickPrompts('same-id').map((p) => p.text).toList();
    expect(a, b);
  });

  test('pickPrompts 对不同 seed 通常得到不同组合', () {
    // 遍历若干 seed，确认并非所有 seed 都返回同一组合
    final combos = <String>{};
    for (int i = 0; i < 12; i++) {
      combos.add(pickPrompts('conv-$i').map((p) => p.text).join('|'));
    }
    expect(combos.length, greaterThan(1));
  });

  test('pickPrompts count 超过库容量时被截断且不越界', () {
    final picked = pickPrompts('x', count: 999);
    expect(picked.length, kPromptPresets.length);
  });
}
