# T8 任务交付摘要 - 内容池扩充 & 推荐负反馈机制

**任务 ID**: tsk-8cf9beca-449  
**执行者**: product_developer (agt-ed4fa121-10c)  
**完成日期**: 2026-03-01  
**代码分支**: `feature/content-pool-and-negative-feedback`  
**仓库**: gdszyy/edge-reader

## 交付物清单

### 1. 内容池扩充

| 文件 | 路径 | 说明 |
| :--- | :--- | :--- |
| `featured-hooks.ts` | `web/src/data/featured-hooks.ts` | 扩充后的冷启动内容池（55篇） |
| `content-pool-management.md` | `docs/content-pool-management.md` | 内容池管理规范文档 |

**扩充详情**:
- 原有 15 篇 → 扩充至 **55 篇**（新增 40 篇）
- 覆盖 **18 个核心领域**（原 8 个）
- 新增领域: 哲学(8篇), 心理学(6篇), 社会学(5篇), 艺术批评(6篇), 科学史(5篇), 人类学(3篇), 数学(3篇), 传播学(2篇), 生态学(2篇)
- 每篇包含: 翻译钩子(bridgeHook) + 认知标签预标注(cognitiveTags)
- 认知标签体系: thinkingPattern / bloomLevel / emotionalTone / crossDomainDistance

### 2. 推荐负反馈机制

| 文件 | 路径 | 说明 |
| :--- | :--- | :--- |
| `FeedbackButton.vue` | `web/src/components/feed/FeedbackButton.vue` | 反馈按钮组件 |
| `SwipeableArticleCard.vue` | `web/src/components/feed/SwipeableArticleCard.vue` | 可滑动文章卡片 |
| `useCardDismiss.ts` | `web/src/composables/useCardDismiss.ts` | 滑动手势 composable |
| `feedbackService.ts` | `web/src/services/feedbackService.ts` | 前端 API 服务 |
| `feedback.go` | `server/api/handler/feedback.go` | 后端反馈 handler |
| `router.go` | `server/api/router.go` | 路由注册（已更新） |

**功能详情**:
- **前端交互**: 长按(600ms)触发"不感兴趣"，点击展开4选项菜单，左滑触发dismiss
- **反馈类型**: `not_interested` / `too_easy` / `too_hard` / `seen_before`
- **后端 API**: `POST /api/v1/recommendations/:id/feedback`
- **权重调整**: 异步降低相关标签权重（30%/20%/10%/15%衰减因子）
- **卡片动画**: 滑出(280ms) + 进度环 + 背景提示 + 新卡片淡入
- **移动端适配**: 触觉反馈(vibrate) + 底部弹出式菜单 + 安全区域

## 数据库迁移

需要创建 `recommendation_feedbacks` 表:

```sql
CREATE TABLE recommendation_feedbacks (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  recommendation_id BIGINT UNSIGNED NOT NULL,
  article_id BIGINT UNSIGNED NOT NULL,
  feedback_type ENUM('not_interested','too_easy','too_hard','seen_before') NOT NULL,
  article_tags JSON,
  recommend_context JSON,
  weight_adjusted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at BIGINT UNSIGNED NOT NULL,
  INDEX idx_user_feedback (user_id),
  INDEX idx_recommendation (recommendation_id),
  INDEX idx_user_article (user_id, article_id)
);
```
