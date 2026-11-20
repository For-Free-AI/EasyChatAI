import 'dart:math';

/// 配置层：首页空状态的快捷提示词预设（v1.8.4）
/// 每次新对话按会话 id 随机抽取 3 条展示；同一会话内保持稳定不闪烁。
class QuickPrompt {
  final String emoji;
  final String text;
  const QuickPrompt(this.emoji, this.text);
}

const List<QuickPrompt> kPromptPresets = [
  QuickPrompt('✨', '帮我写一段产品介绍'),
  QuickPrompt('💻', '解释这段代码的作用'),
  QuickPrompt('🌍', '用中文介绍一个有趣的知识'),
  QuickPrompt('✍️', '帮我润色这段话，让表达更自然'),
  QuickPrompt('📝', '给我写一篇关于坚持的短文'),
  QuickPrompt('🧠', '用一个故事解释什么是区块链'),
  QuickPrompt('🔀', '把这段话翻译成英文'),
  QuickPrompt('📚', '推荐几本值得一读的经典书籍'),
  QuickPrompt('🐛', '帮我找出这段代码里的 bug'),
  QuickPrompt('📊', '解释一下这份数据说明了什么'),
  QuickPrompt('💡', '给我一些提升专注力的小技巧'),
  QuickPrompt('🎯', '帮我制定一份一周学习计划'),
  QuickPrompt('🗣️', '模拟一次英语口语对话练习'),
  QuickPrompt('🍳', '用现有食材给我一个菜谱'),
  QuickPrompt('🎨', '帮我写一个有创意的广告标语'),
  QuickPrompt('📧', '帮我写一封得体的工作邮件'),
  QuickPrompt('⚖️', '对比一下这两个方案的优缺点'),
  QuickPrompt('🔬', '用小学生能听懂的话解释量子力学'),
  QuickPrompt('🗺️', '规划一个三天两晚的旅行路线'),
  QuickPrompt('🤝', '帮我想几个打破陌生人尬聊的话题'),
];

/// 根据 [seed]（通常是当前会话 id）确定性地抽取 [count] 条不重复提示词。
/// 同一个 seed 结果稳定，不同 seed 得到不同组合。
List<QuickPrompt> pickPrompts(String seed, {int count = 3}) {
  final random = Random(seed.hashCode);
  final pool = List<QuickPrompt>.from(kPromptPresets);
  // Fisher-Yates 洗牌
  for (int i = pool.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(count.clamp(0, pool.length)).toList();
}
