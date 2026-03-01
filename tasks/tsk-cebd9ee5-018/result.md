# Sprint2-T19: 认知星图完整可视化与社交分享卡片

## 任务完成摘要

**状态**: 已完成  
**分支**: `feature/sprint2-t19-starmap-share`  
**仓库**: gdszyy/edge-reader  
**提交**: 13 files changed, 3498 insertions(+)

---

## 一、认知星图完整可视化

### 1.1 StarmapView.vue (完整星图页面)
- **位置**: `web/src/views/StarmapView.vue`
- **路由**: `/starmap` (需认证)
- **功能**:
  - 全屏沉浸式星图展示（深色主题）
  - 顶部导航栏（返回/分享/适应视图）
  - 维度图例筛选（点击切换显示/隐藏）
  - 认知摘要面板（底部抽屉式展开）
  - 节点详情弹窗（点击节点查看权重/置信度/证据数等）
  - 时间轴控制器（周维度快照切换）
  - 空状态和加载状态处理
  - 响应式设计（移动端适配）

### 1.2 useForceGraph.ts (Canvas 2D 力导向图引擎)
- **位置**: `web/src/composables/useForceGraph.ts`
- **算法**: Verlet 积分 + 力导向布局
  - 节点间斥力 (Coulomb's law)
  - 连线弹簧力 (Hooke's law)
  - 中心引力 (防止节点飘散)
  - 速度阻尼 + alpha 衰减
- **交互**: 
  - 鼠标: 拖拽节点/平移画布/滚轮缩放/点击选中/悬停高亮
  - 触摸: 单指拖拽/双指缩放
- **渲染**: 
  - 高DPI Canvas 渲染
  - 节点渐变填充 + 光晕效果
  - 连线高亮（悬停关联）
  - 新标签脉冲动画
- **性能**: 支持 100+ 节点流畅渲染

### 1.3 节点可视化规则
| 属性 | 映射规则 |
|------|----------|
| 节点大小 | 8px + weight × 20px (8-28px) |
| 节点颜色 | 理解偏好=#F59E0B, 关注域=#3B82F6, 情绪倾向=#EC4899, 思维方式=#10B981 |
| 连线透明度 | 默认15%, 悬停关联60% |
| 标签字号 | max(10, min(14, radius×0.9)) |

---

## 二、社交分享卡片

### 2.1 ShareCard.vue (分享卡片组件)
- **位置**: `web/src/components/starmap/ShareCard.vue`
- **功能**:
  - 卡片预览（9:16 竖版）
  - 迷你星图 Canvas 渲染（环形布局）
  - 用户头像 + 昵称
  - 认知摘要文本 + 核心特质标签
  - 统计数据（标签数/阅读天数/主导维度）
  - 品牌信息 + 二维码占位
  - html2canvas 截图保存
  - Web Share API / 剪贴板分享

### 2.2 五种背景主题
| 主题 | 名称 | 渐变色 |
|------|------|--------|
| cosmos | 星空宇宙 | #0f0c29 → #302b63 → #24243e |
| aurora | 极光之夜 | #0d1b2a → #1b4332 → #0d1b2a |
| sunset | 暮色余晖 | #1a1a2e → #6b2737 → #e94560 |
| ocean | 深海之境 | #0a1628 → #0e3b5e → #145374 |
| minimal | 极简纯白 | #f8fafc → #e2e8f0 → #f1f5f9 |

### 2.3 ShareView.vue (分享详情公开页面)
- **位置**: `web/src/views/ShareView.vue`
- **路由**: `/share/:shareId` (无需认证)
- **功能**: 展示分享的星图快照 + CTA引导

---

## 三、后端 API

### 3.1 GET /api/v1/users/:id/starmap
- **认证**: 需要 JWT
- **支持**: `id` 可为数字或 `me`
- **响应**: 当前快照 + 8周时间线 + 认知摘要
- **特性**: 
  - 标签时间衰减 (指数衰减)
  - 同维度/跨维度连线构建
  - 连线数量限制 (≤3×节点数)

### 3.2 POST /api/v1/starmap/share
- **认证**: 需要 JWT
- **请求**: theme + includeTimeline + message
- **响应**: shareId + shareUrl + qrCodeUrl + expiresAt
- **有效期**: 7天

### 3.3 GET /api/v1/starmap/share/:shareId
- **认证**: 无需认证（公开接口）
- **功能**: 返回分享快照数据 + 浏览计数

---

## 四、文件清单

### 新增文件 (10个)
| 文件 | 说明 |
|------|------|
| `web/src/views/StarmapView.vue` | 完整星图页面 |
| `web/src/views/ShareView.vue` | 分享详情页面 |
| `web/src/components/starmap/ShareCard.vue` | 分享卡片组件 |
| `web/src/composables/useForceGraph.ts` | 力导向图引擎 |
| `web/src/types/starmap.ts` | 类型定义 |
| `server/internal/starmap/model.go` | 数据模型 |
| `server/internal/starmap/repository.go` | 数据访问层 |
| `server/internal/starmap/service.go` | 业务逻辑层 |
| `server/internal/starmap/handler.go` | HTTP 接口 |
| `server/internal/starmap/routes.go` | 路由注册 |

### 修改文件 (3个)
| 文件 | 修改内容 |
|------|----------|
| `web/src/services/api.ts` | 新增 starmapApi |
| `web/src/router/index.ts` | 新增 /starmap 和 /share/:shareId 路由 |
| `web/src/components/starmap/index.ts` | 导出 ShareCard |

---

## 五、集成说明

### 前端依赖
- `html2canvas`: 需要安装 (`pnpm add html2canvas`)

### 后端集成
在 `server/api/router.go` 中注册路由:
```go
import "github.com/gdszyy/edge-reader/server/internal/starmap"

// 初始化
starmapRepo := starmap.NewRepository(db)
starmapService := starmap.NewService(starmapRepo, adjacencyGraph)
starmapHandler := starmap.NewHandler(starmapService)

// 注册路由
starmap.RegisterRoutes(v1Group, starmapHandler, authMiddleware)
```

### 数据库迁移
需要创建 `starmap_shares` 表:
```sql
CREATE TABLE starmap_shares (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  share_id VARCHAR(36) NOT NULL UNIQUE,
  theme VARCHAR(20) NOT NULL,
  snapshot_data LONGTEXT NOT NULL,
  expires_at BIGINT UNSIGNED NOT NULL,
  view_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at BIGINT UNSIGNED NOT NULL,
  INDEX idx_user_id (user_id),
  INDEX idx_expires_at (expires_at)
);
```
