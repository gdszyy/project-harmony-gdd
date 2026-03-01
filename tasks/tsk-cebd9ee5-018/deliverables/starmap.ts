/**
 * starmap.ts - 认知星图相关类型定义
 *
 * [Sprint2-T19] 认知星图完整可视化与社交分享卡片
 */

import type { CognitiveDimension } from '@/composables/useForceGraph'

// ---- API 响应类型 ----

/** 星图标签节点 */
export interface StarmapNode {
  id: string
  tagName: string
  tagDisplayName: string
  dimension: CognitiveDimension
  weight: number
  confidence: number
  evidenceCount: number
  firstDetectedAt: number
  lastReinforcedAt: number
  decayRate: number
}

/** 星图连线 */
export interface StarmapEdge {
  source: string
  target: string
  distance: number
  type: 'same_dimension' | 'cross_dimension' | 'adjacency'
}

/** 星图时间快照 */
export interface StarmapSnapshot {
  timestamp: number
  label: string           // e.g. "2026-W08", "2026-02"
  nodes: StarmapNode[]
  edges: StarmapEdge[]
}

/** 认知摘要 */
export interface CognitiveSummary {
  totalTags: number
  topDimension: string
  topDimensionLabel: string
  dominantTraits: string[]
  recentGrowth: string[]
  readingDays: number
  insightText: string     // AI 生成的一句话认知总结
}

/** GET /api/v1/users/{id}/starmap 响应 */
export interface StarmapResponse {
  userId: number
  userName: string
  avatarUrl: string
  currentSnapshot: StarmapSnapshot
  timeline: StarmapSnapshot[]
  summary: CognitiveSummary
  generatedAt: number
}

/** 分享卡片主题 */
export type ShareTheme =
  | 'cosmos'      // 宇宙深蓝
  | 'aurora'      // 极光绿
  | 'sunset'      // 日落暖色
  | 'ocean'       // 深海蓝
  | 'minimal'     // 极简白

export interface ShareThemeConfig {
  id: ShareTheme
  name: string
  bgGradient: string
  textColor: string
  accentColor: string
  cardBg: string
}

/** POST /api/v1/starmap/share 请求 */
export interface ShareRequest {
  theme: ShareTheme
  includeTimeline: boolean
  message?: string
}

/** POST /api/v1/starmap/share 响应 */
export interface ShareResponse {
  shareId: string
  shareUrl: string
  qrCodeUrl: string
  expiresAt: number
}

// ---- 分享主题配置 ----
export const SHARE_THEMES: ShareThemeConfig[] = [
  {
    id: 'cosmos',
    name: '星空宇宙',
    bgGradient: 'linear-gradient(135deg, #0f0c29 0%, #302b63 50%, #24243e 100%)',
    textColor: '#E2E8F0',
    accentColor: '#818CF8',
    cardBg: 'rgba(15, 23, 42, 0.85)',
  },
  {
    id: 'aurora',
    name: '极光之夜',
    bgGradient: 'linear-gradient(135deg, #0d1b2a 0%, #1b4332 50%, #0d1b2a 100%)',
    textColor: '#D1FAE5',
    accentColor: '#34D399',
    cardBg: 'rgba(13, 27, 42, 0.85)',
  },
  {
    id: 'sunset',
    name: '暮色余晖',
    bgGradient: 'linear-gradient(135deg, #1a1a2e 0%, #6b2737 50%, #e94560 100%)',
    textColor: '#FDE68A',
    accentColor: '#F59E0B',
    cardBg: 'rgba(26, 26, 46, 0.85)',
  },
  {
    id: 'ocean',
    name: '深海之境',
    bgGradient: 'linear-gradient(135deg, #0a1628 0%, #0e3b5e 50%, #145374 100%)',
    textColor: '#BAE6FD',
    accentColor: '#38BDF8',
    cardBg: 'rgba(10, 22, 40, 0.85)',
  },
  {
    id: 'minimal',
    name: '极简纯白',
    bgGradient: 'linear-gradient(135deg, #f8fafc 0%, #e2e8f0 50%, #f1f5f9 100%)',
    textColor: '#1E293B',
    accentColor: '#6366F1',
    cardBg: 'rgba(255, 255, 255, 0.9)',
  },
]
