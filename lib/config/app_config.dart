/// 配置层：预置的服务商模板 + 应用常量
/// 重点适配 Agnes API（OpenAI 兼容格式）
class AppConfig {
  // ===== Agnes API 预置模板（重点适配）=====
  // 国际站 Base URL
  static const String agnesBaseUrl = 'https://apihub.agnes-ai.com/v1';
  // 中国站 Base URL（备选）
  static const String agnesCnBaseUrl = 'https://api.agnes-ai.cn/v1';
  // 默认模型
  static const String agnesModel = 'agnes-2.5-flash';
  // Chat Completions 完整端点 = baseUrl + /chat/completions
  static const String chatPath = '/chat/completions';

  /// Agnes 推荐模型列表（供设置页下拉选择）
  static const List<String> agnesModels = [
    'agnes-2.5-flash',
    'agnes-2.5-pro',
    'agnes-3.0-flash',
    'agnes-2.0-flash',
  ];

  /// 预置服务商快捷模板：名称 -> {baseUrl, model, protocol}
  /// protocol: 'openai'（Chat Completions 兼容）| 'anthropic'（Messages 兼容）
  static const Map<String, Map<String, String>> presets = {
    'Agnes（国际）': {
      'baseUrl': agnesBaseUrl,
      'model': agnesModel,
      'protocol': 'openai',
    },
    'Agnes（中国）': {
      'baseUrl': agnesCnBaseUrl,
      'model': agnesModel,
      'protocol': 'openai',
    },
    'DeepSeek': {
      'baseUrl': 'https://api.deepseek.com/v1',
      'model': 'deepseek-chat',
      'protocol': 'openai',
    },
    'OpenAI': {
      'baseUrl': 'https://api.openai.com/v1',
      'model': 'gpt-4o-mini',
      'protocol': 'openai',
    },
    // v1.6.0：Anthropic Messages 兼容
    'Anthropic': {
      'baseUrl': anthropicBaseUrl,
      'model': anthropicModel,
      'protocol': 'anthropic',
    },
    // 自定义：清空地址与模型，由用户自行填写任意兼容服务（协议可选）
    '自定义': {'baseUrl': '', 'model': '', 'protocol': 'openai'},
  };

  // ===== v1.6.0 Anthropic Messages 兼容 =====
  static const String anthropicBaseUrl = 'https://api.anthropic.com';
  static const String anthropicModel = 'claude-sonnet-4-5';

  /// Anthropic max_tokens 必填：默认回答长度上限
  static const int anthropicMaxTokens = 4096;

  /// 开启深度思考时的预算（必须小于 max_tokens，开启时 max_tokens 自动加大）
  static const int anthropicThinkingBudget = 4096;

  /// 默认系统提示词（V1.4.3 改为中国用户中文场景）
  static const String defaultSystemPrompt = '你是AI助手，服务对象是中国用户。请用中文回答用户问题。';

  /// 旧版默认提示词：仅用于识别"从未改过默认值"的存量用户并平滑升级，
  /// 用户自定义过的提示词不会被覆盖。
  static const String legacyDefaultSystemPrompt =
      'You are a helpful AI assistant. 请用简洁清晰的中文回答用户问题。';

  /// V1.1 后台自动命名用的提示词：只输出简短中文标题
  static const String titlePrompt =
      '请根据下面的对话内容，生成一个不超过12个字的简短中文标题。'
      '只输出标题本身，不要引号、不要标点、不要任何解释。';

  // ===== V1.3 联网搜索相关 =====
  /// DeepSeek 独立搜索接口（选 DeepSeek 时固定使用，仅需单独填 Key）
  static const String deepseekSearchUrl =
      'https://api.deepseek.com/v1/tools/search';

  /// 联网搜索配置支持的提供商
  static const List<String> searchProviders = ['自定义', 'DeepSeek'];

  /// 让当前模型判断"是否需要联网搜索"的提示词（要求输出 JSON）
  static const String searchJudgePrompt =
      '你是一个搜索决策助手。请判断回答用户问题是否需要联网获取实时信息。'
      '需要联网：涉及时事新闻、最新价格或数据、近期政策、包含"今天/昨天/最新/现在/股价"等时间词、'
      '或你不确定时效性的事实。'
      '不需要联网：通用知识、翻译、写作、代码、数学、情感对话、稳定不变的历史事实。'
      '只输出一个 JSON 对象：{"need": true或false, "query": "用于搜索的关键词"}。'
      '不要输出其他任何文字，不要 markdown 代码块。';

  static const String appName = 'EasyChatAI';
}
