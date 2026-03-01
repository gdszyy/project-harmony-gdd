<template>
  <div class="feedback-container" ref="containerRef">
    <!-- 主按钮：点击展开反馈选项，长按直接触发"不感兴趣" -->
    <button
      class="feedback-trigger"
      :class="{ 'is-active': isMenuOpen, 'is-pressing': isPressing }"
      @mousedown="onPressStart"
      @mouseup="onPressEnd"
      @mouseleave="onPressCancel"
      @touchstart.passive="onTouchStart"
      @touchend="onTouchEnd"
      @touchcancel="onPressCancel"
      @click.stop="toggleMenu"
      :title="isPressing ? '松开以标记不感兴趣' : '反馈'"
      :aria-expanded="isMenuOpen"
      aria-haspopup="true"
    >
      <!-- 长按进度环 -->
      <svg
        v-if="isPressing"
        class="press-progress-ring"
        viewBox="0 0 36 36"
        width="36"
        height="36"
      >
        <circle
          class="progress-bg"
          cx="18" cy="18" r="15"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          opacity="0.15"
        />
        <circle
          class="progress-fill"
          cx="18" cy="18" r="15"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
          :stroke-dasharray="circumference"
          :stroke-dashoffset="progressOffset"
          transform="rotate(-90 18 18)"
        />
      </svg>
      <!-- 默认图标 -->
      <svg
        v-else
        class="feedback-icon"
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <circle cx="12" cy="12" r="1" />
        <circle cx="12" cy="5" r="1" />
        <circle cx="12" cy="19" r="1" />
      </svg>
    </button>

    <!-- 反馈选项菜单 -->
    <Transition name="feedback-menu">
      <div
        v-if="isMenuOpen"
        class="feedback-menu"
        role="menu"
        @click.stop
      >
        <div class="menu-header">
          <span class="menu-title">为什么不感兴趣？</span>
        </div>
        <button
          v-for="option in feedbackOptions"
          :key="option.type"
          class="menu-item"
          :class="{ 'is-selected': selectedType === option.type }"
          role="menuitem"
          @click="submitFeedback(option.type)"
        >
          <span class="menu-item-icon">{{ option.icon }}</span>
          <div class="menu-item-content">
            <span class="menu-item-label">{{ option.label }}</span>
            <span class="menu-item-desc">{{ option.description }}</span>
          </div>
        </button>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'

// ============================================================
// 类型定义
// ============================================================

export type FeedbackType = 'not_interested' | 'too_easy' | 'too_hard' | 'seen_before'

export interface FeedbackOption {
  type: FeedbackType
  label: string
  description: string
  icon: string
}

export interface FeedbackEvent {
  articleId: number
  feedbackType: FeedbackType
}

// ============================================================
// Props & Emits
// ============================================================

const props = defineProps<{
  articleId: number
}>()

const emit = defineEmits<{
  (e: 'feedback', payload: FeedbackEvent): void
  (e: 'dismiss', articleId: number): void
}>()

// ============================================================
// 反馈选项配置
// ============================================================

const feedbackOptions: FeedbackOption[] = [
  {
    type: 'not_interested',
    label: '不感兴趣',
    description: '这个话题不吸引我',
    icon: '😐',
  },
  {
    type: 'too_easy',
    label: '太简单了',
    description: '我已经很了解这个领域',
    icon: '🎓',
  },
  {
    type: 'too_hard',
    label: '太难了',
    description: '超出了我的理解范围',
    icon: '🤯',
  },
  {
    type: 'seen_before',
    label: '看过了',
    description: '我之前读过类似内容',
    icon: '👀',
  },
]

// ============================================================
// 状态
// ============================================================

const containerRef = ref<HTMLElement | null>(null)
const isMenuOpen = ref(false)
const isPressing = ref(false)
const pressProgress = ref(0)
const selectedType = ref<FeedbackType | null>(null)

// 长按相关
const LONG_PRESS_DURATION = 600 // ms
let pressTimer: ReturnType<typeof setTimeout> | null = null
let pressAnimationFrame: number | null = null
let pressStartTime = 0

// 滑动相关
let touchStartX = 0
let touchStartY = 0
const SWIPE_THRESHOLD = 80 // px

// 进度环参数
const circumference = computed(() => 2 * Math.PI * 15)
const progressOffset = computed(
  () => circumference.value * (1 - pressProgress.value)
)

// ============================================================
// 长按处理
// ============================================================

function onPressStart(e: MouseEvent | TouchEvent) {
  isPressing.value = true
  pressProgress.value = 0
  pressStartTime = Date.now()

  // 动画更新进度
  const animateProgress = () => {
    const elapsed = Date.now() - pressStartTime
    pressProgress.value = Math.min(elapsed / LONG_PRESS_DURATION, 1)

    if (pressProgress.value >= 1) {
      // 长按完成，触发"不感兴趣"
      isPressing.value = false
      pressProgress.value = 0
      triggerHapticFeedback()
      submitFeedback('not_interested')
      return
    }

    pressAnimationFrame = requestAnimationFrame(animateProgress)
  }

  pressAnimationFrame = requestAnimationFrame(animateProgress)
}

function onPressEnd() {
  cancelPressAnimation()
  if (isPressing.value && pressProgress.value < 1) {
    // 短按，不触发长按逻辑
    isPressing.value = false
    pressProgress.value = 0
  }
}

function onPressCancel() {
  cancelPressAnimation()
  isPressing.value = false
  pressProgress.value = 0
}

function cancelPressAnimation() {
  if (pressAnimationFrame) {
    cancelAnimationFrame(pressAnimationFrame)
    pressAnimationFrame = null
  }
  if (pressTimer) {
    clearTimeout(pressTimer)
    pressTimer = null
  }
}

// ============================================================
// 触摸/滑动处理
// ============================================================

function onTouchStart(e: TouchEvent) {
  const touch = e.touches[0]
  touchStartX = touch.clientX
  touchStartY = touch.clientY
  onPressStart(e)
}

function onTouchEnd(e: TouchEvent) {
  onPressEnd()

  // 检测滑动
  if (e.changedTouches.length > 0) {
    const touch = e.changedTouches[0]
    const deltaX = touch.clientX - touchStartX
    const deltaY = touch.clientY - touchStartY

    // 左滑超过阈值 → 触发"不感兴趣"
    if (Math.abs(deltaX) > SWIPE_THRESHOLD && Math.abs(deltaX) > Math.abs(deltaY)) {
      if (deltaX < 0) {
        submitFeedback('not_interested')
      }
    }
  }
}

// ============================================================
// 菜单控制
// ============================================================

function toggleMenu() {
  if (isPressing.value) return
  isMenuOpen.value = !isMenuOpen.value
}

function closeMenu() {
  isMenuOpen.value = false
  selectedType.value = null
}

// 点击外部关闭菜单
function handleClickOutside(e: Event) {
  if (containerRef.value && !containerRef.value.contains(e.target as Node)) {
    closeMenu()
  }
}

// ============================================================
// 反馈提交
// ============================================================

function submitFeedback(type: FeedbackType) {
  selectedType.value = type

  // 发射反馈事件
  emit('feedback', {
    articleId: props.articleId,
    feedbackType: type,
  })

  // 发射 dismiss 事件（触发卡片滑出动画）
  emit('dismiss', props.articleId)

  // 关闭菜单
  setTimeout(() => {
    closeMenu()
  }, 200)
}

// ============================================================
// 触觉反馈（移动端）
// ============================================================

function triggerHapticFeedback() {
  if ('vibrate' in navigator) {
    navigator.vibrate(50)
  }
}

// ============================================================
// 生命周期
// ============================================================

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onBeforeUnmount(() => {
  document.removeEventListener('click', handleClickOutside)
  cancelPressAnimation()
})
</script>

<style scoped>
.feedback-container {
  position: relative;
  display: inline-flex;
}

/* ===== 触发按钮 ===== */
.feedback-trigger {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  border-radius: 8px;
  color: oklch(0.60 0.02 250);
  cursor: pointer;
  transition: background 150ms, color 150ms, transform 100ms;
  -webkit-tap-highlight-color: transparent;
  touch-action: manipulation;
}

.feedback-trigger:hover {
  background: oklch(0.93 0.01 250);
  color: oklch(0.45 0.05 250);
}

.feedback-trigger.is-active {
  background: oklch(0.92 0.05 250 / 0.3);
  color: var(--color-primary, oklch(0.55 0.15 250));
}

.feedback-trigger.is-pressing {
  transform: scale(1.1);
  background: oklch(0.93 0.08 25 / 0.2);
  color: oklch(0.55 0.20 25);
}

/* ===== 长按进度环 ===== */
.press-progress-ring {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  pointer-events: none;
}

.progress-fill {
  transition: stroke-dashoffset 16ms linear;
  color: oklch(0.55 0.20 25);
}

/* ===== 反馈菜单 ===== */
.feedback-menu {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  z-index: 100;
  min-width: 240px;
  background: var(--color-card, #fff);
  border: 1px solid oklch(0.88 0.02 250);
  border-radius: 12px;
  box-shadow: 0 8px 32px oklch(0.20 0.02 250 / 0.12),
              0 2px 8px oklch(0.20 0.02 250 / 0.06);
  overflow: hidden;
}

.menu-header {
  padding: 12px 16px 8px;
  border-bottom: 1px solid oklch(0.92 0.01 250);
}

.menu-title {
  font-size: 12px;
  font-weight: 600;
  color: oklch(0.55 0.03 250);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 10px 16px;
  border: none;
  background: transparent;
  cursor: pointer;
  transition: background 120ms;
  text-align: left;
}

.menu-item:hover {
  background: oklch(0.95 0.03 250 / 0.5);
}

.menu-item:active {
  background: oklch(0.92 0.05 250 / 0.5);
}

.menu-item.is-selected {
  background: oklch(0.92 0.08 25 / 0.15);
}

.menu-item-icon {
  font-size: 20px;
  flex-shrink: 0;
  width: 28px;
  text-align: center;
}

.menu-item-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.menu-item-label {
  font-size: 14px;
  font-weight: 500;
  color: var(--color-fg, oklch(0.20 0.02 250));
}

.menu-item-desc {
  font-size: 12px;
  color: oklch(0.60 0.02 250);
}

/* ===== 菜单过渡动画 ===== */
.feedback-menu-enter-active {
  transition: opacity 180ms ease-out, transform 180ms ease-out;
}

.feedback-menu-leave-active {
  transition: opacity 120ms ease-in, transform 120ms ease-in;
}

.feedback-menu-enter-from {
  opacity: 0;
  transform: translateY(-8px) scale(0.95);
}

.feedback-menu-leave-to {
  opacity: 0;
  transform: translateY(-4px) scale(0.98);
}

/* ===== 响应式 ===== */
@media (max-width: 640px) {
  .feedback-menu {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    top: auto;
    min-width: 100%;
    border-radius: 16px 16px 0 0;
    box-shadow: 0 -4px 32px oklch(0.20 0.02 250 / 0.15);
  }

  .menu-header {
    padding: 16px 20px 12px;
    text-align: center;
  }

  .menu-item {
    padding: 14px 20px;
  }

  /* 移动端底部安全区域 */
  .feedback-menu::after {
    content: '';
    display: block;
    height: env(safe-area-inset-bottom, 0px);
  }
}
</style>
