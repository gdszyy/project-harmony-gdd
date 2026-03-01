/**
 * 推荐反馈 API 服务
 *
 * 封装与后端反馈 API 的交互逻辑，包括提交反馈、获取反馈历史等。
 */

import type { FeedbackType } from '@/components/feed/FeedbackButton.vue'

// ============================================================
// 类型定义
// ============================================================

export interface FeedbackRequest {
  feedback_type: FeedbackType
}

export interface FeedbackResponseData {
  id: number
  recommendation_id: number
  feedback_type: FeedbackType
  weight_adjusted: boolean
  message: string
}

export interface ApiResponse<T> {
  code: number
  message: string
  data: T
  timestamp: number
}

export interface FeedbackRecord {
  id: number
  user_id: number
  recommendation_id: number
  article_id: number
  feedback_type: FeedbackType
  weight_adjusted: boolean
  created_at: number
}

// ============================================================
// API 配置
// ============================================================

const API_BASE = import.meta.env.VITE_API_BASE || '/api/v1'

function getAuthHeaders(): Record<string, string> {
  const token = localStorage.getItem('access_token')
  return token
    ? { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }
    : { 'Content-Type': 'application/json' }
}

// ============================================================
// API 方法
// ============================================================

/**
 * 提交推荐反馈
 *
 * @param recommendationId 推荐 ID（当前等同于 articleId）
 * @param feedbackType 反馈类型
 * @returns 反馈响应
 */
export async function submitFeedback(
  recommendationId: number,
  feedbackType: FeedbackType
): Promise<FeedbackResponseData> {
  const url = `${API_BASE}/recommendations/${recommendationId}/feedback`

  const res = await fetch(url, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ feedback_type: feedbackType }),
  })

  if (!res.ok) {
    const errorData = await res.json().catch(() => ({}))
    throw new FeedbackError(
      errorData.message || `反馈提交失败 (${res.status})`,
      res.status,
      errorData.code
    )
  }

  const data: ApiResponse<FeedbackResponseData> = await res.json()
  return data.data
}

/**
 * 获取用户反馈历史
 *
 * @returns 反馈记录列表
 */
export async function getUserFeedbacks(): Promise<FeedbackRecord[]> {
  const url = `${API_BASE}/recommendations/feedbacks`

  const res = await fetch(url, {
    method: 'GET',
    headers: getAuthHeaders(),
  })

  if (!res.ok) {
    throw new FeedbackError('获取反馈历史失败', res.status)
  }

  const data: ApiResponse<FeedbackRecord[]> = await res.json()
  return data.data
}

/**
 * 检查是否已对某推荐提交过反馈（本地缓存优先）
 */
export function hasFeedbackCached(recommendationId: number): boolean {
  const cache = getFeedbackCache()
  return cache.has(recommendationId)
}

/**
 * 将反馈记录添加到本地缓存
 */
export function addToFeedbackCache(recommendationId: number, feedbackType: FeedbackType) {
  const cache = getFeedbackCache()
  cache.set(recommendationId, feedbackType)
  saveFeedbackCache(cache)
}

// ============================================================
// 本地缓存
// ============================================================

const CACHE_KEY = 'edge_reader_feedback_cache'

function getFeedbackCache(): Map<number, FeedbackType> {
  try {
    const raw = localStorage.getItem(CACHE_KEY)
    if (raw) {
      const entries = JSON.parse(raw) as [number, FeedbackType][]
      return new Map(entries)
    }
  } catch {
    // 缓存损坏，清除
    localStorage.removeItem(CACHE_KEY)
  }
  return new Map()
}

function saveFeedbackCache(cache: Map<number, FeedbackType>) {
  try {
    // 只保留最近 500 条
    const entries = Array.from(cache.entries()).slice(-500)
    localStorage.setItem(CACHE_KEY, JSON.stringify(entries))
  } catch {
    // 存储满了，清除旧数据
    localStorage.removeItem(CACHE_KEY)
  }
}

// ============================================================
// 错误类
// ============================================================

export class FeedbackError extends Error {
  public httpStatus: number
  public errorCode?: number

  constructor(message: string, httpStatus: number, errorCode?: number) {
    super(message)
    this.name = 'FeedbackError'
    this.httpStatus = httpStatus
    this.errorCode = errorCode
  }
}
