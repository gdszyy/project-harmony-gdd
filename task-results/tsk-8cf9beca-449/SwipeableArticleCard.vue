<template>
  <div
    class="swipeable-card-wrapper"
    :class="{
      'is-swiping': isSwiping,
      'is-dismissing': isDismissing,
      'is-entering': isEntering,
    }"
  >
    <!-- 滑动背景提示层 -->
    <div class="swipe-background" :class="swipeBackgroundClass">
      <div class="swipe-hint swipe-hint-left" v-if="swipeDirection === 'left'">
        <span class="swipe-hint-icon">😐</span>
        <span class="swipe-hint-text">不感兴趣</span>
      </div>
      <div class="swipe-hint swipe-hint-right" v-if="swipeDirection === 'right'">
        <span class="swipe-hint-icon">🔖</span>
        <span class="swipe-hint-text">稍后再看</span>
      </div>
    </div>

    <!-- 可滑动卡片 -->
    <div
      ref="cardRef"
      class="swipeable-card"
      :style="cardStyle"
      @touchstart="onTouchStart"
      @touchmove.prevent="onTouchMove"
      @touchend="onTouchEnd"
      @mousedown="onMouseDown"
    >
      <!-- 卡片内容 (slot 或默认布局) -->
      <slot>
        <div class="card-content">
          <div class="card-header">
            <span class="card-domain">{{ article.primaryDomain }}</span>
            <FeedbackButton
              :article-id="article.articleId"
              @feedback="handleFeedback"
              @dismiss="handleDismiss"
            />
          </div>
          <h3 class="card-title">{{ article.title }}</h3>
          <p class="card-hook" v-if="article.bridgeHook">
            {{ article.bridgeHook.fullText }}
          </p>
          <div class="card-meta">
            <span class="card-author">{{ article.authorName }}</span>
            <span class="card-reading-time">
              {{ article.estimatedReadingMinutes }} 分钟
            </span>
            <span
              class="card-difficulty"
              :class="`difficulty-${article.difficultyLevel}`"
            >
              {{ difficultyLabel }}
            </span>
          </div>
        </div>
      </slot>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useCardDismiss, type DismissDirection } from '@/composables/useCardDismiss'
import FeedbackButton from './FeedbackButton.vue'
import type { FeedbackEvent } from './FeedbackButton.vue'

// ============================================================
// Props & Emits
// ============================================================

interface ArticleData {
  articleId: number
  title: string
  authorName: string
  primaryDomain: string
  secondaryDomains?: string[]
  estimatedReadingMinutes: number
  difficultyLevel: 'easy' | 'moderate' | 'hard'
  coverImageUrl?: string
  bridgeHook?: {
    knownConcept: string
    newConcept: string
    bridgeExplanation: string
    fullText: string
  }
}

const props = defineProps<{
  article: ArticleData
  index?: number
}>()

const emit = defineEmits<{
  (e: 'feedback', payload: FeedbackEvent): void
  (e: 'dismiss', articleId: number, direction: DismissDirection): void
  (e: 'replace', articleId: number): void
}>()

// ============================================================
// 滑动手势
// ============================================================

const {
  cardRef,
  cardStyle,
  isSwiping,
  isDismissing,
  isEntering,
  onTouchStart,
  onTouchMove,
  onTouchEnd,
  onMouseDown,
  onMouseMove,
  onMouseUp,
  dismiss,
} = useCardDismiss({
  threshold: 100,
  animationDuration: 280,
  onDismiss: (direction) => {
    emit('dismiss', props.article.articleId, direction)
    if (direction === 'left') {
      // 左滑 = 不感兴趣，自动提交反馈
      emit('feedback', {
        articleId: props.article.articleId,
        feedbackType: 'not_interested',
      })
    }
  },
  onReplace: () => {
    emit('replace', props.article.articleId)
  },
})

// 全局鼠标事件（桌面端拖拽需要在 window 上监听）
if (typeof window !== 'undefined') {
  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseup', onMouseUp)
}

// ============================================================
// 计算属性
// ============================================================

const swipeDirection = computed<DismissDirection | null>(() => {
  if (!isSwiping.value) return null
  const style = cardStyle.value as Record<string, string>
  const transform = style.transform || ''
  const match = transform.match(/translateX\((-?\d+\.?\d*)px\)/)
  if (match) {
    const x = parseFloat(match[1])
    if (x < -20) return 'left'
    if (x > 20) return 'right'
  }
  return null
})

const swipeBackgroundClass = computed(() => ({
  'bg-left': swipeDirection.value === 'left',
  'bg-right': swipeDirection.value === 'right',
}))

const difficultyLabel = computed(() => {
  switch (props.article.difficultyLevel) {
    case 'easy': return '入门'
    case 'moderate': return '进阶'
    case 'hard': return '深度'
    default: return ''
  }
})

// ============================================================
// 事件处理
// ============================================================

function handleFeedback(payload: FeedbackEvent) {
  emit('feedback', payload)
}

function handleDismiss(articleId: number) {
  dismiss('left')
}
</script>

<style scoped>
.swipeable-card-wrapper {
  position: relative;
  overflow: hidden;
  border-radius: 16px;
}

/* ===== 滑动背景提示 ===== */
.swipe-background {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  border-radius: 16px;
  opacity: 0;
  transition: opacity 150ms;
}

.swipeable-card-wrapper.is-swiping .swipe-background {
  opacity: 1;
}

.swipe-background.bg-left {
  background: oklch(0.92 0.08 25 / 0.3);
  justify-content: flex-end;
  padding-right: 24px;
}

.swipe-background.bg-right {
  background: oklch(0.92 0.08 145 / 0.3);
  justify-content: flex-start;
  padding-left: 24px;
}

.swipe-hint {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.swipe-hint-icon {
  font-size: 28px;
}

.swipe-hint-text {
  font-size: 12px;
  font-weight: 600;
  color: oklch(0.45 0.10 25);
}

.swipe-background.bg-right .swipe-hint-text {
  color: oklch(0.40 0.12 145);
}

/* ===== 卡片主体 ===== */
.swipeable-card {
  position: relative;
  z-index: 1;
  background: var(--color-card, #fff);
  border: 1px solid oklch(0.90 0.02 250);
  border-radius: 16px;
  overflow: hidden;
  user-select: none;
  -webkit-user-select: none;
}

.swipeable-card-wrapper.is-swiping .swipeable-card {
  box-shadow: 0 8px 32px oklch(0.20 0.02 250 / 0.12);
}

/* ===== 卡片内容 ===== */
.card-content {
  padding: 20px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.card-domain {
  font-size: 12px;
  font-weight: 600;
  color: var(--color-primary, oklch(0.55 0.15 250));
  background: oklch(0.95 0.05 250 / 0.5);
  padding: 4px 10px;
  border-radius: 6px;
  letter-spacing: 0.02em;
}

.card-title {
  font-size: 18px;
  font-weight: 700;
  line-height: 1.4;
  color: var(--color-fg, oklch(0.15 0.02 250));
  margin: 0 0 10px;
}

.card-hook {
  font-size: 14px;
  line-height: 1.65;
  color: oklch(0.45 0.02 250);
  margin: 0 0 16px;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.card-meta {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 12px;
  color: oklch(0.60 0.02 250);
}

.card-author {
  font-weight: 500;
}

.card-reading-time::before {
  content: '·';
  margin-right: 12px;
}

.card-difficulty {
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 500;
  font-size: 11px;
}

.difficulty-easy {
  background: oklch(0.93 0.06 145 / 0.4);
  color: oklch(0.40 0.12 145);
}

.difficulty-moderate {
  background: oklch(0.93 0.06 80 / 0.4);
  color: oklch(0.45 0.12 80);
}

.difficulty-hard {
  background: oklch(0.93 0.06 25 / 0.4);
  color: oklch(0.45 0.12 25);
}

/* ===== 进入动画 ===== */
.swipeable-card-wrapper.is-entering .swipeable-card {
  animation: cardEnter 280ms cubic-bezier(0.32, 0.72, 0, 1) forwards;
}

@keyframes cardEnter {
  from {
    opacity: 0;
    transform: translateY(20px) scale(0.97);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}
</style>
