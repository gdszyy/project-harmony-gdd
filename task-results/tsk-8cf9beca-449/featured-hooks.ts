/**
 * 冷启动编辑精选翻译钩子数据
 *
 * 当用户跳过引导问卷或处于冷启动阶段时，使用这些编辑精选的高质量翻译钩子
 * 填充推荐流。每条钩子都经过精心设计，确保对大多数知识型用户具有吸引力。
 *
 * 设计原则：
 * 1. 跨域桥接：每条钩子连接两个不同的知识领域
 * 2. 反直觉：优先选择能引发"原来如此"感觉的关联
 * 3. 普适性：不依赖特定专业背景即可理解
 * 4. 情感共鸣：文案语气温暖、有启发性
 *
 * 内容池版本: v2.0
 * 更新日期: 2026-03-01
 * 总计: 55 条编辑精选（15 条原始 + 40 条扩充）
 * 领域覆盖: 18 个核心领域
 */

import type { ArticleRecommendation } from '@/types'

export interface FeaturedHookItem {
  articleId: number
  title: string
  authorName: string
  primaryDomain: string
  secondaryDomains: string[]
  estimatedReadingMinutes: number
  difficultyLevel: 'easy' | 'moderate' | 'hard'
  coverImageUrl?: string
  bridgeHook: {
    knownConcept: string
    newConcept: string
    bridgeExplanation: string
    fullText: string
  }
  /** 编辑推荐理由（内部使用，不展示给用户） */
  editorialNote: string
  /** 适合的用户画像标签（用于后续个性化排序） */
  targetTags: string[]
  /** 编辑评分 1-5（用于排序） */
  editorialScore: number
  /** 认知标签预标注（用于推荐引擎的认知维度匹配） */
  cognitiveTags: {
    /** 思维模式: analogy(类比) | systems(系统) | critical(批判) | creative(创造) | historical(历史) | empirical(实证) */
    thinkingPattern: string
    /** 认知层次: remember | understand | apply | analyze | evaluate | create (布鲁姆分类) */
    bloomLevel: string
    /** 情感调性: inspiring | provocative | contemplative | surprising | reassuring */
    emotionalTone: string
    /** 跨域距离: near(1-2步) | medium(3-4步) | far(5+步) */
    crossDomainDistance: 'near' | 'medium' | 'far'
  }
}

/**
 * 编辑精选翻译钩子数据集
 *
 * 覆盖 18 个核心领域，共 55 条精选推荐。
 * 按 editorialScore 降序排列，冷启动时取前 5 条展示。
 */
export const featuredHooks: FeaturedHookItem[] = [
  // ============================================================
  // 原始 15 条编辑精选（ID 101-115）
  // ============================================================

  // ===== 跨域桥接类（最高优先级）=====
  {
    articleId: 101,
    title: '蚁群算法与城市交通规划的隐秘关联',
    authorName: '李明',
    primaryDomain: '计算机科学',
    secondaryDomains: ['城市规划', '生物学'],
    estimatedReadingMinutes: 15,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '导航软件的路线推荐',
      newConcept: '蚂蚁的信息素通信机制',
      bridgeExplanation: '你每天使用的导航软件，其路线优化算法的灵感来源竟然是蚂蚁觅食时留下的化学信号',
      fullText: '你每天使用的导航软件，其路线优化算法的灵感来源竟然是蚂蚁觅食时留下的化学信号。这篇文章揭示了去中心化智慧如何从自然界迁移到城市规划中。',
    },
    editorialNote: '跨域桥接经典案例，生物学→计算机→城市规划三重跨域',
    targetTags: ['analogy', 'systems_thinking', 'technology'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'far',
    },
  },
  {
    articleId: 102,
    title: '为什么星巴克的菜单设计能让你多花 30%',
    authorName: '张薇',
    primaryDomain: '行为经济学',
    secondaryDomains: ['心理学', '商业'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '点咖啡时的选择困难',
      newConcept: '锚定效应与诱饵定价',
      bridgeExplanation: '你在星巴克犹豫要不要升杯的那一刻，其实已经被精心设计的"锚定效应"捕获了',
      fullText: '你在星巴克犹豫要不要升杯的那一刻，其实已经被精心设计的"锚定效应"捕获了。这篇文章用日常消费场景解密行为经济学的核心原理。',
    },
    editorialNote: '入门级行为经济学，日常场景切入，几乎所有用户都能共鸣',
    targetTags: ['psychology', 'economics', 'daily_life'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 103,
    title: '从乐高积木到软件架构：模块化思维的千年演化',
    authorName: '王浩然',
    primaryDomain: '设计思维',
    secondaryDomains: ['计算机科学', '历史'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '乐高积木的拼装逻辑',
      newConcept: '软件微服务架构的设计哲学',
      bridgeExplanation: '乐高积木和现代软件架构共享同一个底层设计哲学——模块化',
      fullText: '乐高积木和现代软件架构共享同一个底层设计哲学——模块化。这篇文章追溯了从古罗马建筑到今天的微服务，模块化思维如何反复改变世界。',
    },
    editorialNote: '模块化思维的跨时代叙事，设计→工程→历史三重视角',
    targetTags: ['analogy', 'design', 'systems_thinking'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'analyze',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 104,
    title: '你的大脑如何在 0.1 秒内决定信任一个陌生人',
    authorName: '陈思远',
    primaryDomain: '认知科学',
    secondaryDomains: ['心理学', '社会学'],
    estimatedReadingMinutes: 8,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '第一印象的力量',
      newConcept: '杏仁核的快速威胁评估机制',
      bridgeExplanation: '你对陌生人的第一印象，其实是大脑杏仁核在 100 毫秒内完成的一次"安全扫描"',
      fullText: '你对陌生人的第一印象，其实是大脑杏仁核在 100 毫秒内完成的一次"安全扫描"。这篇文章揭示了信任的神经科学基础，以及为什么我们的直觉有时惊人地准确。',
    },
    editorialNote: '认知科学入门，与日常社交体验直接关联',
    targetTags: ['psychology', 'cognitive_science', 'social'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'empirical',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 105,
    title: '股票市场与地震：幂律分布下的共同规律',
    authorName: '刘博文',
    primaryDomain: '复杂系统',
    secondaryDomains: ['经济学', '物理学'],
    estimatedReadingMinutes: 14,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '股票市场的剧烈波动',
      newConcept: '幂律分布与自组织临界性',
      bridgeExplanation: '股票市场的崩盘和地震的发生频率，竟然遵循完全相同的数学规律',
      fullText: '股票市场的崩盘和地震的发生频率，竟然遵循完全相同的数学规律——幂律分布。这篇文章揭示了看似无关的复杂系统背后共享的深层秩序。',
    },
    editorialNote: '反直觉发现类，经济学与物理学的意外交汇',
    targetTags: ['economics', 'physics', 'pattern_recognition'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'far',
    },
  },

  // ===== 方法迁移类 =====
  {
    articleId: 106,
    title: '进化论如何帮助 Netflix 找到你想看的电影',
    authorName: '赵雅琪',
    primaryDomain: '人工智能',
    secondaryDomains: ['生物学', '商业'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: 'Netflix 的推荐算法',
      newConcept: '遗传算法与自然选择',
      bridgeExplanation: 'Netflix 推荐系统的核心算法之一，直接借鉴了达尔文进化论中"适者生存"的机制',
      fullText: 'Netflix 推荐系统的核心算法之一，直接借鉴了达尔文进化论中"适者生存"的机制。这篇文章展示了生物学原理如何被工程师转化为商业利器。',
    },
    editorialNote: '方法迁移经典案例，生物学→AI→商业',
    targetTags: ['technology', 'biology', 'analogy'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'apply',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 107,
    title: '博弈论视角下的国际气候谈判',
    authorName: '孙立伟',
    primaryDomain: '经济学',
    secondaryDomains: ['政治学', '环境科学'],
    estimatedReadingMinutes: 13,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '囚徒困境的经典博弈',
      newConcept: '气候谈判中的公地悲剧',
      bridgeExplanation: '国际气候谈判的僵局，本质上是一场放大版的"囚徒困境"',
      fullText: '国际气候谈判的僵局，本质上是一场放大版的"囚徒困境"。这篇文章用博弈论框架解读为什么各国明知气候危机却难以合作。',
    },
    editorialNote: '经济学方法迁移到政治学，时事相关性强',
    targetTags: ['economics', 'politics', 'game_theory'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'medium',
    },
  },

  // ===== 反直觉发现类 =====
  {
    articleId: 108,
    title: '为什么最高效的团队往往不是最和谐的',
    authorName: '周晓峰',
    primaryDomain: '管理学',
    secondaryDomains: ['心理学', '社会学'],
    estimatedReadingMinutes: 9,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '团队协作中的和谐氛围',
      newConcept: '建设性冲突与认知多样性',
      bridgeExplanation: '你追求的团队和谐，可能正是阻碍创新的最大障碍',
      fullText: '你追求的团队和谐，可能正是阻碍创新的最大障碍。这篇文章基于 Google 的 Project Aristotle 研究，揭示了高效团队的真正秘密。',
    },
    editorialNote: '反直觉管理学，职场人群高共鸣',
    targetTags: ['management', 'psychology', 'contrarian'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 109,
    title: '混乱的书桌与创造力：熵增定律的人文解读',
    authorName: '林雨桐',
    primaryDomain: '哲学',
    secondaryDomains: ['物理学', '心理学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '整理书桌的强迫症',
      newConcept: '热力学第二定律与创造性混沌',
      bridgeExplanation: '物理学的熵增定律暗示，适度的混乱可能是创造力的必要条件',
      fullText: '物理学的熵增定律暗示，适度的混乱可能是创造力的必要条件。这篇文章从一张凌乱的书桌出发，探讨秩序与混沌之间的哲学张力。',
    },
    editorialNote: '哲学+物理学的轻松跨域，日常场景切入',
    targetTags: ['philosophy', 'physics', 'creativity'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'creative',
      bloomLevel: 'analyze',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'medium',
    },
  },

  // ===== 底层规律类 =====
  {
    articleId: 110,
    title: '城市为什么像生物体一样生长',
    authorName: '杨思涵',
    primaryDomain: '城市规划',
    secondaryDomains: ['生物学', '复杂系统'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '城市的扩张与拥堵',
      newConcept: '异速生长定律（Allometric Scaling）',
      bridgeExplanation: '城市的基础设施增长速度与城市规模的关系，遵循与生物体完全相同的数学定律',
      fullText: '城市的基础设施增长速度与城市规模的关系，遵循与生物体完全相同的数学定律。这篇文章揭示了为什么大城市既更高效又更拥挤。',
    },
    editorialNote: '底层规律类，Geoffrey West 的标度理论通俗化',
    targetTags: ['urban_planning', 'biology', 'scaling_laws'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'far',
    },
  },
  {
    articleId: 111,
    title: '语言如何塑造你看世界的方式',
    authorName: '吴语嫣',
    primaryDomain: '语言学',
    secondaryDomains: ['认知科学', '哲学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '学外语时的思维转换感',
      newConcept: '萨丕尔-沃尔夫假说与语言相对论',
      bridgeExplanation: '你学外语时感受到的"思维方式不同"，背后是一个争论了近百年的语言学假说',
      fullText: '你学外语时感受到的"思维方式不同"，背后是一个争论了近百年的语言学假说。这篇文章探讨语言是否真的限制了我们的思维边界。',
    },
    editorialNote: '语言学入门，几乎所有有外语学习经历的人都能共鸣',
    targetTags: ['linguistics', 'cognitive_science', 'philosophy'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 112,
    title: '从围棋到蛋白质折叠：AlphaGo 团队的第二次革命',
    authorName: '黄子轩',
    primaryDomain: '人工智能',
    secondaryDomains: ['生物学', '医学'],
    estimatedReadingMinutes: 15,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: 'AlphaGo 击败围棋世界冠军',
      newConcept: 'AlphaFold 解决蛋白质折叠问题',
      bridgeExplanation: '击败围棋冠军的 AI 技术，被同一个团队用来解决了困扰生物学家 50 年的蛋白质折叠问题',
      fullText: '击败围棋冠军的 AI 技术，被同一个团队用来解决了困扰生物学家 50 年的蛋白质折叠问题。这篇文章讲述了 DeepMind 如何将游戏 AI 转化为科学突破。',
    },
    editorialNote: 'AI 领域标志性事件，科技用户高兴趣',
    targetTags: ['ai', 'biology', 'technology'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'understand',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'far',
    },
  },
  {
    articleId: 113,
    title: '日本庭园与极简主义设计的共同美学',
    authorName: '田中美咲',
    primaryDomain: '设计',
    secondaryDomains: ['哲学', '文化'],
    estimatedReadingMinutes: 8,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: 'Apple 产品的极简设计',
      newConcept: '侘寂美学与"留白"哲学',
      bridgeExplanation: 'Apple 的极简设计哲学，与日本庭园中的"侘寂"美学有着深刻的精神共鸣',
      fullText: 'Apple 的极简设计哲学，与日本庭园中的"侘寂"美学有着深刻的精神共鸣。这篇文章探讨了东西方在"少即是多"上的不谋而合。',
    },
    editorialNote: '设计+文化跨域，视觉审美类用户高兴趣',
    targetTags: ['design', 'philosophy', 'culture'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'creative',
      bloomLevel: 'evaluate',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 114,
    title: '为什么历史上的帝国都在 250 年左右崩溃',
    authorName: '马骏',
    primaryDomain: '历史学',
    secondaryDomains: ['社会学', '复杂系统'],
    estimatedReadingMinutes: 14,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '罗马帝国的衰亡',
      newConcept: '社会复杂度与边际收益递减',
      bridgeExplanation: '从罗马到奥斯曼，帝国的平均寿命惊人地相似，背后是一个关于复杂度的经济学规律',
      fullText: '从罗马到奥斯曼，帝国的平均寿命惊人地相似，背后是一个关于复杂度的经济学规律。这篇文章用 Joseph Tainter 的理论解读帝国兴衰的数学模式。',
    },
    editorialNote: '历史+经济学跨域，宏大叙事类',
    targetTags: ['history', 'economics', 'pattern_recognition'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'analyze',
      emotionalTone: 'provocative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 115,
    title: '冥想如何改变大脑的物理结构',
    authorName: '许静怡',
    primaryDomain: '神经科学',
    secondaryDomains: ['心理学', '健康'],
    estimatedReadingMinutes: 9,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '冥想让人感觉更平静',
      newConcept: '神经可塑性与灰质密度变化',
      bridgeExplanation: '冥想不只是"感觉好"——fMRI 扫描显示，8 周的冥想练习能显著改变大脑的物理结构',
      fullText: '冥想不只是"感觉好"——fMRI 扫描显示，8 周的冥想练习能显著改变大脑的物理结构。这篇文章用硬科学数据解读冥想的神经科学基础。',
    },
    editorialNote: '健康+科学跨域，个人成长类用户高兴趣',
    targetTags: ['neuroscience', 'psychology', 'health'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'empirical',
      bloomLevel: 'understand',
      emotionalTone: 'reassuring',
      crossDomainDistance: 'near',
    },
  },

  // ============================================================
  // 扩充内容：哲学领域（ID 201-208）
  // ============================================================
  {
    articleId: 201,
    title: '存在主义咖啡馆：萨特为什么说"他人即地狱"',
    authorName: '陆文渊',
    primaryDomain: '哲学',
    secondaryDomains: ['心理学', '文学'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '社交中的被评判焦虑',
      newConcept: '萨特的"注视"理论与存在主义自由',
      bridgeExplanation: '你在社交场合感到不自在的那种感觉，萨特在 1943 年就给出了一个惊人的哲学解释',
      fullText: '你在社交场合感到不自在的那种感觉，萨特在 1943 年就给出了一个惊人的哲学解释——"他人的注视"让我们意识到自己成了客体。这篇文章用咖啡馆里的日常场景，带你走进存在主义的核心命题。',
    },
    editorialNote: '存在主义入门，社交焦虑切入点，年轻用户高共鸣',
    targetTags: ['philosophy', 'psychology', 'existentialism', 'social'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'understand',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 202,
    title: '电车难题之后：道德直觉能否被信任',
    authorName: '方哲明',
    primaryDomain: '哲学',
    secondaryDomains: ['认知科学', '伦理学'],
    estimatedReadingMinutes: 14,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '经典的电车难题',
      newConcept: '道德基础理论与双过程模型',
      bridgeExplanation: '电车难题不只是一个思想实验——fMRI 研究发现，你的道德判断其实是两个脑区在"打架"',
      fullText: '电车难题不只是一个思想实验——fMRI 研究发现，你的道德判断其实是两个脑区在"打架"。这篇文章从哲学经典出发，探讨神经科学如何重新定义伦理学的边界。',
    },
    editorialNote: '伦理学+神经科学跨域，经典思想实验的现代解读',
    targetTags: ['philosophy', 'ethics', 'neuroscience', 'contrarian'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 203,
    title: '庄子的蝴蝶与虚拟现实：两千年前的模拟假说',
    authorName: '沈若兰',
    primaryDomain: '哲学',
    secondaryDomains: ['计算机科学', '东方哲学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: 'VR 虚拟现实体验',
      newConcept: '庄周梦蝶与模拟假说',
      bridgeExplanation: '你戴上 VR 头盔时的那种"这是不是真实的"困惑，庄子在两千年前就思考过了',
      fullText: '你戴上 VR 头盔时的那种"这是不是真实的"困惑，庄子在两千年前就思考过了。这篇文章将庄周梦蝶、笛卡尔的恶魔和 Nick Bostrom 的模拟假说串联起来，追问现实的本质。',
    },
    editorialNote: '东西方哲学对话，科技切入点降低门槛',
    targetTags: ['philosophy', 'eastern_philosophy', 'technology', 'metaphysics'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'analyze',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'far',
    },
  },
  {
    articleId: 204,
    title: '维特根斯坦的语言游戏：为什么你和父母总是"说不通"',
    authorName: '顾言之',
    primaryDomain: '哲学',
    secondaryDomains: ['语言学', '社会学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '与父母沟通时的代沟感',
      newConcept: '维特根斯坦的"语言游戏"与"生活形式"',
      bridgeExplanation: '你和父母之间的沟通障碍，可能不是态度问题，而是你们在玩两种完全不同的"语言游戏"',
      fullText: '你和父母之间的沟通障碍，可能不是态度问题，而是你们在玩两种完全不同的"语言游戏"。维特根斯坦认为，语言的意义来自使用它的"生活形式"——这篇文章用家庭沟通场景解读分析哲学的核心洞见。',
    },
    editorialNote: '分析哲学通俗化，家庭关系切入，情感共鸣强',
    targetTags: ['philosophy', 'linguistics', 'family', 'communication'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'apply',
      emotionalTone: 'reassuring',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 205,
    title: '尼采的"永恒回归"：如果人生无限循环，你会怎么活',
    authorName: '陆文渊',
    primaryDomain: '哲学',
    secondaryDomains: ['心理学', '物理学'],
    estimatedReadingMinutes: 13,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '对人生选择的后悔',
      newConcept: '尼采的永恒回归思想实验',
      bridgeExplanation: '如果你的人生会一模一样地无限重复，你现在做的每一个选择还值得吗？尼采用这个问题检验生命的意义',
      fullText: '如果你的人生会一模一样地无限重复，你现在做的每一个选择还值得吗？尼采用这个问题检验生命的意义。这篇文章将永恒回归与现代物理学的循环宇宙假说对照，探讨如何活出"值得重复"的人生。',
    },
    editorialNote: '尼采哲学入门，个人成长类用户高兴趣',
    targetTags: ['philosophy', 'existentialism', 'personal_growth', 'physics'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 206,
    title: '福柯的监控社会：从圆形监狱到智能手机',
    authorName: '方哲明',
    primaryDomain: '哲学',
    secondaryDomains: ['社会学', '技术批评'],
    estimatedReadingMinutes: 15,
    difficultyLevel: 'hard',
    bridgeHook: {
      knownConcept: '手机 App 的隐私追踪',
      newConcept: '福柯的全景监狱与规训权力',
      bridgeExplanation: '你手机里的每个 App 都在追踪你——福柯在 1975 年就预言了这种"看不见的监控"如何塑造行为',
      fullText: '你手机里的每个 App 都在追踪你——福柯在 1975 年就预言了这种"看不见的监控"如何塑造行为。这篇文章从边沁的圆形监狱出发，追溯到当代数字监控社会，揭示权力如何通过"可见性"运作。',
    },
    editorialNote: '福柯思想的当代应用，隐私议题切入，科技用户高关注',
    targetTags: ['philosophy', 'sociology', 'technology', 'privacy', 'power'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 207,
    title: '斯多葛哲学与硅谷 CEO：两千年前的心理韧性训练',
    authorName: '沈若兰',
    primaryDomain: '哲学',
    secondaryDomains: ['心理学', '商业'],
    estimatedReadingMinutes: 9,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '工作压力与焦虑管理',
      newConcept: '斯多葛主义的"控制二分法"',
      bridgeExplanation: '硅谷最流行的心理韧性框架，其实来自两千年前的古罗马哲学家',
      fullText: '硅谷最流行的心理韧性框架，其实来自两千年前的古罗马哲学家。这篇文章解读斯多葛哲学的核心——"控制二分法"，以及为什么 Tim Ferriss 和 Jack Dorsey 都是它的信徒。',
    },
    editorialNote: '实用哲学，职场压力管理切入，广泛受众',
    targetTags: ['philosophy', 'stoicism', 'psychology', 'business', 'personal_growth'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'apply',
      emotionalTone: 'reassuring',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 208,
    title: '罗尔斯的"无知之幕"：如何设计一个公平的社会',
    authorName: '顾言之',
    primaryDomain: '哲学',
    secondaryDomains: ['政治学', '经济学'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '对社会不公平的愤怒',
      newConcept: '罗尔斯的"无知之幕"思想实验',
      bridgeExplanation: '如果你不知道自己出生后会是富人还是穷人，你会设计一个什么样的社会？这就是罗尔斯最著名的思想实验',
      fullText: '如果你不知道自己出生后会是富人还是穷人，你会设计一个什么样的社会？这就是罗尔斯最著名的思想实验。这篇文章用"无知之幕"框架重新审视当代社会的公平问题。',
    },
    editorialNote: '政治哲学经典，社会公平议题，广泛共鸣',
    targetTags: ['philosophy', 'politics', 'economics', 'justice'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },

  // ============================================================
  // 扩充内容：心理学领域（ID 209-214）
  // ============================================================
  {
    articleId: 209,
    title: '为什么你总在深夜做出后悔的决定：自我损耗理论',
    authorName: '林晓薇',
    primaryDomain: '心理学',
    secondaryDomains: ['神经科学', '行为经济学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '深夜冲动消费或暴饮暴食',
      newConcept: '自我损耗与意志力的"肌肉模型"',
      bridgeExplanation: '你深夜刷手机买了一堆不需要的东西，不是因为你意志力差——而是因为意志力像肌肉一样会"累"',
      fullText: '你深夜刷手机买了一堆不需要的东西，不是因为你意志力差——而是因为意志力像肌肉一样会"累"。这篇文章解读 Roy Baumeister 的自我损耗理论，以及为什么奥巴马只穿灰色西装。',
    },
    editorialNote: '日常行为心理学，几乎所有人都有深夜冲动消费经历',
    targetTags: ['psychology', 'behavioral_economics', 'daily_life', 'self_control'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'empirical',
      bloomLevel: 'understand',
      emotionalTone: 'reassuring',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 210,
    title: '依恋理论：你的恋爱模式在婴儿期就已注定？',
    authorName: '苏雨晴',
    primaryDomain: '心理学',
    secondaryDomains: ['发展心理学', '社会学'],
    estimatedReadingMinutes: 13,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '恋爱中的安全感焦虑',
      newConcept: 'Bowlby 依恋理论与成人依恋类型',
      bridgeExplanation: '你在恋爱中是"黏人型"还是"回避型"，可能与你 18 个月大时和母亲的互动模式有关',
      fullText: '你在恋爱中是"黏人型"还是"回避型"，可能与你 18 个月大时和母亲的互动模式有关。这篇文章从 Bowlby 的依恋理论出发，揭示早期经历如何塑造我们一生的亲密关系模式。',
    },
    editorialNote: '发展心理学经典，亲密关系切入，年轻用户高兴趣',
    targetTags: ['psychology', 'relationships', 'development', 'attachment'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'empirical',
      bloomLevel: 'analyze',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 211,
    title: '斯坦福监狱实验的真相：权力如何腐蚀普通人',
    authorName: '林晓薇',
    primaryDomain: '心理学',
    secondaryDomains: ['社会学', '伦理学'],
    estimatedReadingMinutes: 14,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '职场中的权力滥用',
      newConcept: '情境主义与路西法效应',
      bridgeExplanation: '普通人在获得权力后 6 天就可能变成施虐者——这个经典实验揭示了人性中最令人不安的一面',
      fullText: '普通人在获得权力后 6 天就可能变成施虐者——这个经典实验揭示了人性中最令人不安的一面。但近年来的重新审视发现，真相可能比我们以为的更复杂。这篇文章重新解读斯坦福监狱实验及其争议。',
    },
    editorialNote: '经典心理学实验的批判性重读，权力议题',
    targetTags: ['psychology', 'sociology', 'power', 'ethics', 'contrarian'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 212,
    title: '心流状态：为什么打游戏比工作更让你专注',
    authorName: '苏雨晴',
    primaryDomain: '心理学',
    secondaryDomains: ['神经科学', '设计'],
    estimatedReadingMinutes: 9,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '打游戏时忘记时间的体验',
      newConcept: '契克森米哈伊的心流理论',
      bridgeExplanation: '你打游戏时那种"忘我"的状态，心理学家称之为"心流"——而工作也可以被设计成触发心流的体验',
      fullText: '你打游戏时那种"忘我"的状态，心理学家称之为"心流"——而工作也可以被设计成触发心流的体验。这篇文章解读 Csikszentmihalyi 的心流理论，以及游戏设计师如何利用它让你上瘾。',
    },
    editorialNote: '积极心理学经典，游戏玩家和职场人群双重共鸣',
    targetTags: ['psychology', 'flow', 'gaming', 'productivity', 'design'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'apply',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 213,
    title: '认知失调：为什么花更多钱买的东西你反而更喜欢',
    authorName: '林晓薇',
    primaryDomain: '心理学',
    secondaryDomains: ['行为经济学', '营销学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '买了贵东西后拼命找理由说服自己',
      newConcept: 'Festinger 的认知失调理论',
      bridgeExplanation: '你花大价钱买了一双鞋后觉得它特别好看，不是因为它真的好看，而是你的大脑在"自我欺骗"',
      fullText: '你花大价钱买了一双鞋后觉得它特别好看，不是因为它真的好看，而是你的大脑在"自我欺骗"以消除认知失调。这篇文章揭示了人类最普遍的心理防御机制之一。',
    },
    editorialNote: '认知失调理论通俗化，消费场景切入',
    targetTags: ['psychology', 'behavioral_economics', 'daily_life', 'cognitive_bias'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 214,
    title: '集体无意识：为什么全世界的神话都有"英雄之旅"',
    authorName: '苏雨晴',
    primaryDomain: '心理学',
    secondaryDomains: ['人类学', '文学'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '漫威电影的英雄叙事套路',
      newConcept: '荣格的集体无意识与坎贝尔的英雄之旅',
      bridgeExplanation: '从《星球大战》到《哈利·波特》，所有伟大故事都在重复同一个古老的叙事结构——荣格认为这来自人类共享的"集体无意识"',
      fullText: '从《星球大战》到《哈利·波特》，所有伟大故事都在重复同一个古老的叙事结构——荣格认为这来自人类共享的"集体无意识"。这篇文章追溯坎贝尔的"英雄之旅"理论，揭示为什么某些故事能跨越文化打动所有人。',
    },
    editorialNote: '荣格心理学+叙事学，流行文化切入',
    targetTags: ['psychology', 'mythology', 'literature', 'culture', 'jungian'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'analyze',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'medium',
    },
  },

  // ============================================================
  // 扩充内容：社会学领域（ID 215-219）
  // ============================================================
  {
    articleId: 215,
    title: '弱关系的力量：为什么点赞之交比密友更能帮你找工作',
    authorName: '何思远',
    primaryDomain: '社会学',
    secondaryDomains: ['网络科学', '职业发展'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '社交媒体上的"点赞之交"',
      newConcept: 'Granovetter 的弱关系理论',
      bridgeExplanation: '你微信里那些从不聊天的"僵尸好友"，可能比你的密友更能帮你找到下一份工作',
      fullText: '你微信里那些从不聊天的"僵尸好友"，可能比你的密友更能帮你找到下一份工作。社会学家 Granovetter 发现，弱关系才是信息流通的关键桥梁。这篇文章用社交网络理论解读为什么"广撒网"比"深交往"更有效。',
    },
    editorialNote: '社会网络理论经典，职场人群高实用性',
    targetTags: ['sociology', 'network_science', 'career', 'social_media'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'apply',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 216,
    title: '破窗效应：一扇破窗如何引发一座城市的犯罪浪潮',
    authorName: '何思远',
    primaryDomain: '社会学',
    secondaryDomains: ['城市规划', '犯罪学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '小区环境脏乱差导致治安变差',
      newConcept: '破窗理论与社会规范的传染性',
      bridgeExplanation: '一扇没有修补的破窗，可以像病毒一样传染，最终让整个社区陷入犯罪的恶性循环',
      fullText: '一扇没有修补的破窗，可以像病毒一样传染，最终让整个社区陷入犯罪的恶性循环。这篇文章解读 Wilson 和 Kelling 的破窗理论，以及纽约市如何用"修窗户"策略将犯罪率降低了 75%。',
    },
    editorialNote: '社会学经典理论，城市生活切入',
    targetTags: ['sociology', 'urban_planning', 'criminology', 'social_norms'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 217,
    title: '消费社会的符号学：你买的不是商品，是身份',
    authorName: '唐诗韵',
    primaryDomain: '社会学',
    secondaryDomains: ['哲学', '营销学'],
    estimatedReadingMinutes: 13,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '奢侈品消费与品牌崇拜',
      newConcept: '鲍德里亚的符号消费理论',
      bridgeExplanation: '你买一个 LV 包不是因为它装东西更好——鲍德里亚说你买的是一个"符号"，用来告诉世界你是谁',
      fullText: '你买一个 LV 包不是因为它装东西更好——鲍德里亚说你买的是一个"符号"，用来告诉世界你是谁。这篇文章用消费社会学的视角解读为什么品牌能让人心甘情愿地支付溢价。',
    },
    editorialNote: '消费社会学，品牌消费切入，广泛共鸣',
    targetTags: ['sociology', 'philosophy', 'consumerism', 'semiotics'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'analyze',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 218,
    title: '信息茧房：算法如何把你困在自己的回音室里',
    authorName: '何思远',
    primaryDomain: '社会学',
    secondaryDomains: ['传播学', '计算机科学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '刷短视频越刷越同质化',
      newConcept: '桑斯坦的信息茧房与过滤气泡',
      bridgeExplanation: '你刷短视频越来越无聊，不是因为内容变少了，而是算法正在用你的喜好建造一座"信息监狱"',
      fullText: '你刷短视频越来越无聊，不是因为内容变少了，而是算法正在用你的喜好建造一座"信息监狱"。这篇文章解读桑斯坦的"信息茧房"理论，以及为什么推荐算法可能正在侵蚀民主。',
    },
    editorialNote: '信息茧房理论，短视频用户高共鸣，与产品本身相关',
    targetTags: ['sociology', 'media', 'algorithm', 'democracy', 'filter_bubble'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 219,
    title: '六度分隔理论：你和任何人之间只隔六个人',
    authorName: '唐诗韵',
    primaryDomain: '社会学',
    secondaryDomains: ['网络科学', '数学'],
    estimatedReadingMinutes: 9,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '社交媒体上的"共同好友"',
      newConcept: '小世界网络与六度分隔实验',
      bridgeExplanation: '你和美国总统之间可能只隔 6 个人——这不是都市传说，而是经过数学验证的网络规律',
      fullText: '你和美国总统之间可能只隔 6 个人——这不是都市传说，而是经过数学验证的网络规律。这篇文章从 Milgram 的经典实验到 Facebook 的大数据验证，揭示社交网络的惊人结构。',
    },
    editorialNote: '社会网络经典，趣味性强，入门友好',
    targetTags: ['sociology', 'network_science', 'mathematics', 'social_media'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },

  // ============================================================
  // 扩充内容：艺术批评领域（ID 220-225）
  // ============================================================
  {
    articleId: 220,
    title: '为什么毕加索的画看起来像小孩画的，却价值上亿',
    authorName: '周墨白',
    primaryDomain: '艺术批评',
    secondaryDomains: ['美学', '心理学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '"我也能画"的观展体验',
      newConcept: '立体主义的认知革命与"看"的方式',
      bridgeExplanation: '你觉得毕加索的画像小孩画的？其实他 14 岁就能画得比大多数成人好——他花了一辈子学习"像小孩一样画画"',
      fullText: '你觉得毕加索的画像小孩画的？其实他 14 岁就能画得比大多数成人好——他花了一辈子学习"像小孩一样画画"。这篇文章解读立体主义如何打破了文艺复兴以来 500 年的视觉传统，重新定义了"看"的方式。',
    },
    editorialNote: '艺术批评入门，"看不懂现代艺术"的共鸣切入',
    targetTags: ['art', 'aesthetics', 'visual_arts', 'cubism', 'perception'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'creative',
      bloomLevel: 'evaluate',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 221,
    title: '电影中的"不可靠叙述者"：导演如何让你心甘情愿被骗',
    authorName: '秦乐天',
    primaryDomain: '艺术批评',
    secondaryDomains: ['叙事学', '认知科学'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '《搏击俱乐部》的结局反转',
      newConcept: '不可靠叙述者与认知偏差的艺术利用',
      bridgeExplanation: '《搏击俱乐部》的结局让你震惊，不是因为导演欺骗了你，而是他利用了你大脑的"确认偏差"',
      fullText: '《搏击俱乐部》的结局让你震惊，不是因为导演欺骗了你，而是他利用了你大脑的"确认偏差"。这篇文章从叙事学和认知科学的双重视角，解读电影如何通过"不可靠叙述者"技巧操控观众的心理。',
    },
    editorialNote: '电影批评+认知科学跨域，影迷用户高兴趣',
    targetTags: ['art', 'film', 'narrative', 'cognitive_science', 'perception'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 222,
    title: '音乐为什么能让你起鸡皮疙瘩：音乐情感的神经科学',
    authorName: '周墨白',
    primaryDomain: '艺术批评',
    secondaryDomains: ['神经科学', '音乐学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '听到某首歌时的强烈情感反应',
      newConcept: '音乐期望违背与多巴胺释放',
      bridgeExplanation: '音乐让你起鸡皮疙瘩的那一刻，你的大脑正在释放与吃巧克力和坠入爱河相同的化学物质',
      fullText: '音乐让你起鸡皮疙瘩的那一刻，你的大脑正在释放与吃巧克力和坠入爱河相同的化学物质。这篇文章用神经科学解读音乐情感的生理机制，揭示为什么贝多芬的和弦进行能跨越 200 年打动你。',
    },
    editorialNote: '音乐+神经科学跨域，音乐爱好者高共鸣',
    targetTags: ['art', 'music', 'neuroscience', 'emotion', 'aesthetics'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'empirical',
      bloomLevel: 'understand',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 223,
    title: '建筑如何操控你的情绪：空间心理学入门',
    authorName: '秦乐天',
    primaryDomain: '艺术批评',
    secondaryDomains: ['建筑学', '心理学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '走进大教堂时的敬畏感',
      newConcept: '空间心理学与建筑的情感设计',
      bridgeExplanation: '你走进大教堂时感到的敬畏，不是因为宗教——而是因为建筑师精心计算了天花板高度与你瞳孔扩张的关系',
      fullText: '你走进大教堂时感到的敬畏，不是因为宗教——而是因为建筑师精心计算了天花板高度与你瞳孔扩张的关系。这篇文章从空间心理学的角度，揭示建筑如何通过比例、光线和材质操控人的情绪。',
    },
    editorialNote: '建筑+心理学跨域，空间体验切入',
    targetTags: ['art', 'architecture', 'psychology', 'spatial', 'design'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 224,
    title: '摄影的"决定性瞬间"：布列松如何用 1/125 秒定义一个时代',
    authorName: '周墨白',
    primaryDomain: '艺术批评',
    secondaryDomains: ['哲学', '视觉文化'],
    estimatedReadingMinutes: 9,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '用手机拍照时追求"完美一刻"',
      newConcept: '布列松的"决定性瞬间"理论',
      bridgeExplanation: '你用手机连拍 20 张选最好的一张——布列松说真正的摄影是在按下快门前就已经"看到"了那个瞬间',
      fullText: '你用手机连拍 20 张选最好的一张——布列松说真正的摄影是在按下快门前就已经"看到"了那个瞬间。这篇文章探讨"决定性瞬间"理论如何改变了我们理解时间、记忆和视觉真相的方式。',
    },
    editorialNote: '摄影美学，手机摄影用户广泛共鸣',
    targetTags: ['art', 'photography', 'philosophy', 'visual_culture', 'time'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'creative',
      bloomLevel: 'evaluate',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 225,
    title: '杜尚的小便池如何颠覆了整个艺术史',
    authorName: '秦乐天',
    primaryDomain: '艺术批评',
    secondaryDomains: ['哲学', '文化研究'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '"这也算艺术？"的困惑',
      newConcept: '杜尚的现成品艺术与"艺术体制论"',
      bridgeExplanation: '1917 年，一个男人把小便池送进美术馆，从此改变了"什么是艺术"的定义——这可能是 20 世纪最重要的艺术事件',
      fullText: '1917 年，一个男人把小便池送进美术馆，从此改变了"什么是艺术"的定义——这可能是 20 世纪最重要的艺术事件。这篇文章从杜尚的《泉》出发，探讨艺术的本质是否在于物品本身，还是在于"被称为艺术"的行为。',
    },
    editorialNote: '当代艺术入门，"看不懂当代艺术"的共鸣',
    targetTags: ['art', 'philosophy', 'contemporary_art', 'aesthetics', 'contrarian'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },

  // ============================================================
  // 扩充内容：科学史领域（ID 226-230）
  // ============================================================
  {
    articleId: 226,
    title: '科学革命的结构：为什么科学不是"渐进式进步"',
    authorName: '钱学森（非本人）',
    primaryDomain: '科学史',
    secondaryDomains: ['哲学', '科学方法论'],
    estimatedReadingMinutes: 14,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '"科学是不断进步的"常识',
      newConcept: '库恩的范式转移理论',
      bridgeExplanation: '你以为科学是一步步前进的？库恩说不——科学是通过"革命"来跳跃式发展的，就像政治革命一样',
      fullText: '你以为科学是一步步前进的？库恩说不——科学是通过"革命"来跳跃式发展的，就像政治革命一样。这篇文章解读 Thomas Kuhn 的《科学革命的结构》，揭示"范式转移"如何改变了我们对科学本身的理解。',
    },
    editorialNote: '科学哲学经典，挑战"科学进步"的常识认知',
    targetTags: ['science_history', 'philosophy', 'paradigm_shift', 'methodology'],
    editorialScore: 5,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 227,
    title: '被遗忘的女科学家：罗莎琳德·富兰克林与 DNA 双螺旋的真相',
    authorName: '郑雅文',
    primaryDomain: '科学史',
    secondaryDomains: ['生物学', '性别研究'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: 'Watson 和 Crick 发现 DNA 双螺旋',
      newConcept: '罗莎琳德·富兰克林的 X 射线衍射照片',
      bridgeExplanation: 'DNA 双螺旋的发现者是 Watson 和 Crick？真正拍下关键证据的女科学家，却被历史抹去了',
      fullText: 'DNA 双螺旋的发现者是 Watson 和 Crick？真正拍下关键证据的女科学家罗莎琳德·富兰克林，却被历史抹去了。这篇文章还原科学史上最著名的"功劳窃取"事件，探讨性别偏见如何扭曲了科学叙事。',
    },
    editorialNote: '科学史+性别议题，故事性强，情感共鸣',
    targetTags: ['science_history', 'biology', 'gender', 'justice', 'dna'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 228,
    title: '炼金术士如何意外发明了现代化学',
    authorName: '钱学森（非本人）',
    primaryDomain: '科学史',
    secondaryDomains: ['化学', '哲学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '炼金术是伪科学',
      newConcept: '从炼金术到化学的范式转换',
      bridgeExplanation: '你以为炼金术只是骗子的把戏？牛顿一生中花在炼金术上的时间比物理学还多——而现代化学正是从这些"失败"中诞生的',
      fullText: '你以为炼金术只是骗子的把戏？牛顿一生中花在炼金术上的时间比物理学还多——而现代化学正是从这些"失败"中诞生的。这篇文章追溯从炼金术到化学的转变，揭示"错误的追求"如何意外推动了科学进步。',
    },
    editorialNote: '科学史的反直觉叙事，炼金术→化学的演变',
    targetTags: ['science_history', 'chemistry', 'philosophy', 'contrarian', 'serendipity'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 229,
    title: '爱因斯坦的"奇迹年"：一个专利局职员如何改变物理学',
    authorName: '郑雅文',
    primaryDomain: '科学史',
    secondaryDomains: ['物理学', '创造力研究'],
    estimatedReadingMinutes: 13,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: 'E=mc² 的著名公式',
      newConcept: '1905 年"奇迹年"与思想实验方法',
      bridgeExplanation: '1905 年，一个 26 岁的专利局小职员在一年内发表了 4 篇论文，彻底改写了物理学——他的秘密武器不是实验室，而是"思想实验"',
      fullText: '1905 年，一个 26 岁的专利局小职员在一年内发表了 4 篇论文，彻底改写了物理学——他的秘密武器不是实验室，而是"思想实验"。这篇文章还原爱因斯坦的"奇迹年"，探讨创造性突破的条件。',
    },
    editorialNote: '爱因斯坦传记式科学史，创造力议题',
    targetTags: ['science_history', 'physics', 'creativity', 'thought_experiment'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'understand',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 230,
    title: '青霉素的发现：一次实验室失误如何拯救了数亿人',
    authorName: '钱学森（非本人）',
    primaryDomain: '科学史',
    secondaryDomains: ['医学', '创新研究'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '生病了吃抗生素',
      newConcept: '弗莱明的意外发现与"有准备的心灵"',
      bridgeExplanation: '你生病时吃的抗生素，起源于 1928 年一个科学家忘记清洗培养皿的"失误"——但为什么只有他注意到了？',
      fullText: '你生病时吃的抗生素，起源于 1928 年一个科学家忘记清洗培养皿的"失误"——但为什么只有他注意到了？这篇文章讲述青霉素的发现故事，探讨"偶然性"在科学发现中的角色，以及巴斯德所说的"机遇只偏爱有准备的心灵"。',
    },
    editorialNote: '科学史经典故事，偶然性与创新',
    targetTags: ['science_history', 'medicine', 'serendipity', 'innovation'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'understand',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'near',
    },
  },

  // ============================================================
  // 扩充内容：人类学领域（ID 231-233）
  // ============================================================
  {
    articleId: 231,
    title: '为什么所有文化都有禁忌食物：饮食人类学入门',
    authorName: '白若溪',
    primaryDomain: '人类学',
    secondaryDomains: ['社会学', '生物学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '不同文化的饮食禁忌（如伊斯兰教不吃猪肉）',
      newConcept: 'Mary Douglas 的"洁净与危险"理论',
      bridgeExplanation: '为什么穆斯林不吃猪肉、印度教不吃牛肉、犹太教有复杂的饮食律法？人类学家发现，食物禁忌的本质是"分类系统"',
      fullText: '为什么穆斯林不吃猪肉、印度教不吃牛肉、犹太教有复杂的饮食律法？人类学家 Mary Douglas 发现，食物禁忌的本质是"分类系统"——被禁止的食物往往是那些"跨越了分类边界"的东西。这篇文章用饮食人类学揭示文化如何通过食物建构秩序。',
    },
    editorialNote: '人类学入门，饮食文化切入，跨文化视角',
    targetTags: ['anthropology', 'culture', 'food', 'classification', 'taboo'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 232,
    title: '礼物经济：为什么有些社会不用钱也能运转',
    authorName: '白若溪',
    primaryDomain: '人类学',
    secondaryDomains: ['经济学', '社会学'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '过年发红包的社交义务',
      newConcept: '莫斯的"礼物"理论与互惠原则',
      bridgeExplanation: '你过年收到红包后觉得"必须回礼"的那种压力，人类学家莫斯说这是人类社会最古老的经济系统',
      fullText: '你过年收到红包后觉得"必须回礼"的那种压力，人类学家莫斯说这是人类社会最古老的经济系统。这篇文章从太平洋岛民的"夸富宴"到中国的人情社会，揭示"礼物"如何在没有货币的社会中维持秩序。',
    },
    editorialNote: '经济人类学，中国人情社会切入',
    targetTags: ['anthropology', 'economics', 'gift_economy', 'reciprocity', 'culture'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'analyze',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 233,
    title: '仪式的力量：为什么人类离不开"没有用"的行为',
    authorName: '白若溪',
    primaryDomain: '人类学',
    secondaryDomains: ['心理学', '宗教学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '运动员比赛前的迷信仪式',
      newConcept: '仪式行为的进化心理学解释',
      bridgeExplanation: '纳达尔每次发球前要摸鼻子、整头发——这些"没用"的仪式行为，可能是人类进化中保留下来的焦虑管理机制',
      fullText: '纳达尔每次发球前要摸鼻子、整头发——这些"没用"的仪式行为，可能是人类进化中保留下来的焦虑管理机制。这篇文章从体育迷信到宗教仪式，探讨为什么人类天生需要"仪式感"。',
    },
    editorialNote: '人类学+进化心理学，体育迷信切入',
    targetTags: ['anthropology', 'psychology', 'ritual', 'evolution', 'religion'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'empirical',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },

  // ============================================================
  // 扩充内容：数学哲学领域（ID 234-236）
  // ============================================================
  {
    articleId: 234,
    title: '哥德尔不完备定理：数学为什么无法证明自己是对的',
    authorName: '陈逻辑',
    primaryDomain: '数学',
    secondaryDomains: ['哲学', '计算机科学'],
    estimatedReadingMinutes: 15,
    difficultyLevel: 'hard',
    bridgeHook: {
      knownConcept: '数学是最"确定"的学科',
      newConcept: '哥德尔不完备定理与数学的局限性',
      bridgeExplanation: '你以为数学是绝对真理？1931 年，一个 25 岁的逻辑学家证明了数学永远无法证明自己是完备的——这是人类理性的终极边界',
      fullText: '你以为数学是绝对真理？1931 年，一个 25 岁的逻辑学家证明了数学永远无法证明自己是完备的——这是人类理性的终极边界。这篇文章用尽可能通俗的方式解读哥德尔不完备定理，以及它对哲学和计算机科学的深远影响。',
    },
    editorialNote: '数学哲学巅峰，高难度但极具吸引力',
    targetTags: ['mathematics', 'philosophy', 'logic', 'computer_science', 'limits_of_reason'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'provocative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 235,
    title: '黄金比例的神话与真相：自然界真的偏爱 1.618 吗',
    authorName: '陈逻辑',
    primaryDomain: '数学',
    secondaryDomains: ['美学', '生物学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '黄金比例是"最美的比例"',
      newConcept: '斐波那契数列与进化优化',
      bridgeExplanation: '你听说过黄金比例是"宇宙最美的比例"——但这可能是历史上最成功的数学营销骗局之一',
      fullText: '你听说过黄金比例是"宇宙最美的比例"——但这可能是历史上最成功的数学营销骗局之一。这篇文章区分黄金比例的真实数学之美与被过度神话的部分，揭示斐波那契数列在自然界中的真正角色。',
    },
    editorialNote: '数学美学，打破流行迷思',
    targetTags: ['mathematics', 'aesthetics', 'biology', 'myth_busting', 'fibonacci'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'evaluate',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },
  {
    articleId: 236,
    title: '无穷的悖论：希尔伯特旅馆为什么永远有空房',
    authorName: '陈逻辑',
    primaryDomain: '数学',
    secondaryDomains: ['哲学', '逻辑学'],
    estimatedReadingMinutes: 11,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '酒店满房了就没有空房',
      newConcept: '康托尔的无穷集合论与希尔伯特旅馆悖论',
      bridgeExplanation: '一家住满了无穷多客人的旅馆，还能再容纳无穷多新客人——这不是脑筋急转弯，而是数学家对"无穷"本质的严肃思考',
      fullText: '一家住满了无穷多客人的旅馆，还能再容纳无穷多新客人——这不是脑筋急转弯，而是数学家对"无穷"本质的严肃思考。这篇文章通过希尔伯特旅馆悖论，带你走进康托尔的无穷集合论，体验数学中最令人眩晕的概念。',
    },
    editorialNote: '数学趣味入门，悖论切入降低门槛',
    targetTags: ['mathematics', 'philosophy', 'logic', 'infinity', 'paradox'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'critical',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'near',
    },
  },

  // ============================================================
  // 扩充内容：传播学/媒体研究（ID 237-238）
  // ============================================================
  {
    articleId: 237,
    title: '媒介即讯息：麦克卢汉如何预言了短视频时代',
    authorName: '叶知秋',
    primaryDomain: '传播学',
    secondaryDomains: ['哲学', '技术批评'],
    estimatedReadingMinutes: 12,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '短视频改变了人的注意力',
      newConcept: '麦克卢汉的"媒介即讯息"理论',
      bridgeExplanation: '你觉得短视频让人变傻？60 年前的传播学家麦克卢汉就预言了——真正改变你的不是内容，而是"媒介"本身',
      fullText: '你觉得短视频让人变傻？60 年前的传播学家麦克卢汉就预言了——真正改变你的不是内容，而是"媒介"本身。这篇文章重读麦克卢汉的经典理论，揭示为什么从印刷术到短视频，每一次媒介革命都重塑了人类的思维方式。',
    },
    editorialNote: '传播学经典，短视频时代的重新解读',
    targetTags: ['media', 'philosophy', 'technology', 'mcluhan', 'attention'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'historical',
      bloomLevel: 'analyze',
      emotionalTone: 'provocative',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 238,
    title: '模因论：为什么有些梗能病毒式传播',
    authorName: '叶知秋',
    primaryDomain: '传播学',
    secondaryDomains: ['生物学', '文化研究'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '网络上的"梗"和"meme"',
      newConcept: '道金斯的模因论与文化进化',
      bridgeExplanation: '"meme"这个词不是互联网发明的——它来自进化生物学家道金斯，他认为文化的传播方式和基因一模一样',
      fullText: '"meme"这个词不是互联网发明的——它来自进化生物学家道金斯，他认为文化的传播方式和基因一模一样。这篇文章从道金斯的模因论出发，解读为什么有些梗能跨越语言和文化边界病毒式传播。',
    },
    editorialNote: '模因论+网络文化，年轻用户高兴趣',
    targetTags: ['media', 'biology', 'culture', 'meme', 'viral'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'analogy',
      bloomLevel: 'understand',
      emotionalTone: 'surprising',
      crossDomainDistance: 'medium',
    },
  },

  // ============================================================
  // 扩充内容：生态学/环境科学（ID 239-240）
  // ============================================================
  {
    articleId: 239,
    title: '黄石公园的狼如何改变了河流的走向',
    authorName: '谢山河',
    primaryDomain: '生态学',
    secondaryDomains: ['复
杂系统', '环境科学'],
    estimatedReadingMinutes: 10,
    difficultyLevel: 'easy',
    bridgeHook: {
      knownConcept: '生态系统中的食物链',
      newConcept: '营养级联效应与关键种理论',
      bridgeExplanation: '1995 年，黄石公园重新引入了 14 只狼——结果不仅鹿群数量变了，连河流的走向都改变了',
      fullText: '1995 年，黄石公园重新引入了 14 只狼——结果不仅鹿群数量变了，连河流的走向都改变了。这篇文章通过黄石公园的经典案例，揭示"营养级联效应"如何让一个物种的回归重塑整个生态系统。',
    },
    editorialNote: '生态学经典案例，故事性强，视觉想象力丰富',
    targetTags: ['ecology', 'systems_thinking', 'environment', 'trophic_cascade'],
    editorialScore: 4,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'understand',
      emotionalTone: 'inspiring',
      crossDomainDistance: 'medium',
    },
  },
  {
    articleId: 240,
    title: '盖亚假说：地球本身是一个活的有机体吗',
    authorName: '谢山河',
    primaryDomain: '生态学',
    secondaryDomains: ['哲学', '地球科学'],
    estimatedReadingMinutes: 13,
    difficultyLevel: 'moderate',
    bridgeHook: {
      knownConcept: '"地球母亲"的文化隐喻',
      newConcept: 'Lovelock 的盖亚假说与地球系统科学',
      bridgeExplanation: '"地球是活的"不只是一个浪漫的比喻——科学家 Lovelock 提出，地球的大气、海洋和生物圈确实像一个自我调节的有机体',
      fullText: '"地球是活的"不只是一个浪漫的比喻——科学家 Lovelock 提出，地球的大气、海洋和生物圈确实像一个自我调节的有机体。这篇文章从盖亚假说出发，探讨地球系统科学如何改变了我们对生命与环境关系的理解。',
    },
    editorialNote: '生态哲学，宏大叙事，环保意识用户高兴趣',
    targetTags: ['ecology', 'philosophy', 'earth_science', 'gaia', 'systems_thinking'],
    editorialScore: 3,
    cognitiveTags: {
      thinkingPattern: 'systems',
      bloomLevel: 'evaluate',
      emotionalTone: 'contemplative',
      crossDomainDistance: 'far',
    },
  },
]

/**
 * 获取冷启动推荐列表
 *
 * @param count 返回的推荐数量（默认5）
 * @returns 按编辑评分排序的推荐列表
 */
export function getColdStartRecommendations(count: number = 5): ArticleRecommendation[] {
  return featuredHooks
    .sort((a, b) => b.editorialScore - a.editorialScore)
    .slice(0, count)
    .map((item) => ({
      articleId: item.articleId,
      title: item.title,
      authorName: item.authorName,
      primaryDomain: item.primaryDomain,
      secondaryDomains: item.secondaryDomains,
      estimatedReadingMinutes: item.estimatedReadingMinutes,
      difficultyLevel: item.difficultyLevel,
      coverImageUrl: item.coverImageUrl,
      bridgeHook: item.bridgeHook,
    }))
}

/**
 * 根据用户已读文章过滤推荐
 *
 * @param readArticleIds 已读文章ID列表
 * @param count 返回数量
 * @returns 过滤后的推荐列表
 */
export function getFilteredColdStartRecommendations(
  readArticleIds: number[],
  count: number = 5
): ArticleRecommendation[] {
  return featuredHooks
    .filter((item) => !readArticleIds.includes(item.articleId))
    .sort((a, b) => b.editorialScore - a.editorialScore)
    .slice(0, count)
    .map((item) => ({
      articleId: item.articleId,
      title: item.title,
      authorName: item.authorName,
      primaryDomain: item.primaryDomain,
      secondaryDomains: item.secondaryDomains,
      estimatedReadingMinutes: item.estimatedReadingMinutes,
      difficultyLevel: item.difficultyLevel,
      coverImageUrl: item.coverImageUrl,
      bridgeHook: item.bridgeHook,
    }))
}

/**
 * 根据认知标签筛选推荐
 *
 * @param thinkingPattern 目标思维模式
 * @param count 返回数量
 * @returns 匹配认知标签的推荐列表
 */
export function getRecommendationsByThinkingPattern(
  thinkingPattern: string,
  count: number = 5
): ArticleRecommendation[] {
  return featuredHooks
    .filter((item) => item.cognitiveTags.thinkingPattern === thinkingPattern)
    .sort((a, b) => b.editorialScore - a.editorialScore)
    .slice(0, count)
    .map((item) => ({
      articleId: item.articleId,
      title: item.title,
      authorName: item.authorName,
      primaryDomain: item.primaryDomain,
      secondaryDomains: item.secondaryDomains,
      estimatedReadingMinutes: item.estimatedReadingMinutes,
      difficultyLevel: item.difficultyLevel,
      coverImageUrl: item.coverImageUrl,
      bridgeHook: item.bridgeHook,
    }))
}

/**
 * 根据跨域距离筛选推荐
 *
 * @param distance 跨域距离
 * @param count 返回数量
 * @returns 匹配跨域距离的推荐列表
 */
export function getRecommendationsByCrossDomainDistance(
  distance: 'near' | 'medium' | 'far',
  count: number = 5
): ArticleRecommendation[] {
  return featuredHooks
    .filter((item) => item.cognitiveTags.crossDomainDistance === distance)
    .sort((a, b) => b.editorialScore - a.editorialScore)
    .slice(0, count)
    .map((item) => ({
      articleId: item.articleId,
      title: item.title,
      authorName: item.authorName,
      primaryDomain: item.primaryDomain,
      secondaryDomains: item.secondaryDomains,
      estimatedReadingMinutes: item.estimatedReadingMinutes,
      difficultyLevel: item.difficultyLevel,
      coverImageUrl: item.coverImageUrl,
      bridgeHook: item.bridgeHook,
    }))
}

/**
 * 获取内容池统计信息
 */
export function getContentPoolStats() {
  const domainCounts: Record<string, number> = {}
  const difficultyCounts: Record<string, number> = { easy: 0, moderate: 0, hard: 0 }
  const thinkingPatternCounts: Record<string, number> = {}
  const bloomLevelCounts: Record<string, number> = {}

  featuredHooks.forEach((item) => {
    // 主领域统计
    domainCounts[item.primaryDomain] = (domainCounts[item.primaryDomain] || 0) + 1
    // 难度统计
    difficultyCounts[item.difficultyLevel]++
    // 思维模式统计
    const tp = item.cognitiveTags.thinkingPattern
    thinkingPatternCounts[tp] = (thinkingPatternCounts[tp] || 0) + 1
    // 布鲁姆层次统计
    const bl = item.cognitiveTags.bloomLevel
    bloomLevelCounts[bl] = (bloomLevelCounts[bl] || 0) + 1
  })

  return {
    totalCount: featuredHooks.length,
    domainCounts,
    difficultyCounts,
    thinkingPatternCounts,
    bloomLevelCounts,
  }
}
