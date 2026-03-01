/**
 * useCardDismiss - 卡片滑出替换动画 Composable
 *
 * 提供卡片的滑动手势识别、滑出动画和替换逻辑。
 * 支持左滑（不感兴趣）和右滑（保存/收藏）两种手势方向。
 *
 * 使用方式：
 * ```vue
 * <script setup>
 * import { useCardDismiss } from '@/composables/useCardDismiss'
 *
 * const { cardRef, cardStyle, onTouchStart, onTouchMove, onTouchEnd, dismiss } =
 *   useCardDismiss({
 *     onDismiss: (direction) => { ... },
 *     threshold: 120,
 *   })
 * </script>
 *
 * <template>
 *   <div
 *     ref="cardRef"
 *     :style="cardStyle"
 *     @touchstart="onTouchStart"
 *     @touchmove="onTouchMove"
 *     @touchend="onTouchEnd"
 *   >
 *     ...
 *   </div>
 * </template>
 * ```
 */

import { ref, computed, type Ref } from 'vue'

export type DismissDirection = 'left' | 'right'

export interface UseCardDismissOptions {
  /** 触发滑出的最小距离（px） */
  threshold?: number
  /** 滑出动画持续时间（ms） */
  animationDuration?: number
  /** 滑出后的回调 */
  onDismiss?: (direction: DismissDirection) => void
  /** 替换新卡片的回调 */
  onReplace?: () => void
}

export interface UseCardDismissReturn {
  /** 绑定到卡片元素的 ref */
  cardRef: Ref<HTMLElement | null>
  /** 卡片的动态样式 */
  cardStyle: Ref<Record<string, string>>
  /** 是否正在滑动 */
  isSwiping: Ref<boolean>
  /** 是否正在执行滑出动画 */
  isDismissing: Ref<boolean>
  /** 是否正在执行进入动画 */
  isEntering: Ref<boolean>
  /** 触摸事件处理器 */
  onTouchStart: (e: TouchEvent) => void
  onTouchMove: (e: TouchEvent) => void
  onTouchEnd: (e: TouchEvent) => void
  /** 鼠标事件处理器（桌面端） */
  onMouseDown: (e: MouseEvent) => void
  onMouseMove: (e: MouseEvent) => void
  onMouseUp: (e: MouseEvent) => void
  /** 编程式触发滑出 */
  dismiss: (direction: DismissDirection) => Promise<void>
  /** 重置卡片状态 */
  reset: () => void
}

export function useCardDismiss(options: UseCardDismissOptions = {}): UseCardDismissReturn {
  const {
    threshold = 120,
    animationDuration = 300,
    onDismiss,
    onReplace,
  } = options

  // ===== 状态 =====
  const cardRef = ref<HTMLElement | null>(null)
  const isSwiping = ref(false)
  const isDismissing = ref(false)
  const isEntering = ref(false)

  // 滑动追踪
  let startX = 0
  let startY = 0
  let currentX = 0
  let isTracking = false

  // 动态样式
  const translateX = ref(0)
  const opacity = ref(1)
  const rotation = ref(0)

  const cardStyle = computed(() => {
    if (isDismissing.value) {
      return {
        transform: `translateX(${translateX.value}px) rotate(${rotation.value}deg)`,
        opacity: `${opacity.value}`,
        transition: `transform ${animationDuration}ms cubic-bezier(0.32, 0.72, 0, 1), opacity ${animationDuration}ms ease-out`,
        willChange: 'transform, opacity',
      }
    }

    if (isEntering.value) {
      return {
        transform: 'translateX(0) rotate(0deg) scale(1)',
        opacity: '1',
        transition: `transform ${animationDuration}ms cubic-bezier(0.32, 0.72, 0, 1), opacity ${animationDuration * 0.6}ms ease-out`,
        willChange: 'transform, opacity',
      }
    }

    if (isSwiping.value) {
      return {
        transform: `translateX(${translateX.value}px) rotate(${rotation.value}deg)`,
        opacity: `${opacity.value}`,
        transition: 'none',
        willChange: 'transform, opacity',
        cursor: 'grabbing',
      }
    }

    return {
      transform: 'translateX(0) rotate(0deg)',
      opacity: '1',
      transition: `transform ${animationDuration}ms cubic-bezier(0.32, 0.72, 0, 1)`,
      cursor: 'grab',
    }
  })

  // ===== 滑动计算 =====
  function updateSwipeState(deltaX: number) {
    translateX.value = deltaX
    // 旋转角度与滑动距离成正比，最大 ±15°
    rotation.value = (deltaX / threshold) * 8
    rotation.value = Math.max(-15, Math.min(15, rotation.value))
    // 透明度随滑动距离衰减
    const progress = Math.abs(deltaX) / threshold
    opacity.value = Math.max(0.3, 1 - progress * 0.5)
  }

  function resetSwipeState() {
    translateX.value = 0
    opacity.value = 1
    rotation.value = 0
    isSwiping.value = false
    isTracking = false
  }

  // ===== 触摸事件 =====
  function onTouchStart(e: TouchEvent) {
    if (isDismissing.value || isEntering.value) return
    const touch = e.touches[0]
    startX = touch.clientX
    startY = touch.clientY
    currentX = 0
    isTracking = true
  }

  function onTouchMove(e: TouchEvent) {
    if (!isTracking || isDismissing.value) return
    const touch = e.touches[0]
    const deltaX = touch.clientX - startX
    const deltaY = touch.clientY - startY

    // 判断是水平滑动还是垂直滚动
    if (!isSwiping.value) {
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 10) {
        isSwiping.value = true
        e.preventDefault()
      } else if (Math.abs(deltaY) > 10) {
        // 垂直滚动，停止追踪
        isTracking = false
        return
      }
    }

    if (isSwiping.value) {
      e.preventDefault()
      currentX = deltaX
      updateSwipeState(deltaX)
    }
  }

  function onTouchEnd(_e: TouchEvent) {
    if (!isTracking) return

    if (isSwiping.value && Math.abs(currentX) >= threshold) {
      // 超过阈值，触发滑出
      const direction: DismissDirection = currentX < 0 ? 'left' : 'right'
      executeDismiss(direction)
    } else {
      // 未超过阈值，回弹
      resetSwipeState()
    }
  }

  // ===== 鼠标事件（桌面端） =====
  function onMouseDown(e: MouseEvent) {
    if (isDismissing.value || isEntering.value) return
    startX = e.clientX
    startY = e.clientY
    currentX = 0
    isTracking = true
    // 防止文本选中
    e.preventDefault()
  }

  function onMouseMove(e: MouseEvent) {
    if (!isTracking || isDismissing.value) return
    const deltaX = e.clientX - startX
    const deltaY = e.clientY - startY

    if (!isSwiping.value) {
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 10) {
        isSwiping.value = true
      } else if (Math.abs(deltaY) > 10) {
        isTracking = false
        return
      }
    }

    if (isSwiping.value) {
      currentX = deltaX
      updateSwipeState(deltaX)
    }
  }

  function onMouseUp(_e: MouseEvent) {
    if (!isTracking) return

    if (isSwiping.value && Math.abs(currentX) >= threshold) {
      const direction: DismissDirection = currentX < 0 ? 'left' : 'right'
      executeDismiss(direction)
    } else {
      resetSwipeState()
    }
  }

  // ===== 滑出动画执行 =====
  async function executeDismiss(direction: DismissDirection) {
    isDismissing.value = true
    isSwiping.value = false

    // 计算滑出目标位置（屏幕外）
    const screenWidth = window.innerWidth
    const targetX = direction === 'left' ? -screenWidth * 1.5 : screenWidth * 1.5
    const targetRotation = direction === 'left' ? -30 : 30

    translateX.value = targetX
    rotation.value = targetRotation
    opacity.value = 0

    // 等待动画完成
    await new Promise((resolve) => setTimeout(resolve, animationDuration))

    // 触发回调
    onDismiss?.(direction)

    // 准备新卡片进入动画
    await playEnterAnimation()

    isDismissing.value = false
  }

  // ===== 新卡片进入动画 =====
  async function playEnterAnimation() {
    isEntering.value = true

    // 设置初始状态（从下方淡入）
    translateX.value = 0
    rotation.value = 0
    opacity.value = 0

    // 触发替换回调（更新数据）
    onReplace?.()

    // 等待一帧让 DOM 更新
    await new Promise((resolve) => requestAnimationFrame(resolve))

    // 执行进入动画
    opacity.value = 1

    // 等待动画完成
    await new Promise((resolve) => setTimeout(resolve, animationDuration))

    isEntering.value = false
  }

  // ===== 编程式触发 =====
  async function dismiss(direction: DismissDirection) {
    if (isDismissing.value || isEntering.value) return
    await executeDismiss(direction)
  }

  function reset() {
    resetSwipeState()
    isDismissing.value = false
    isEntering.value = false
  }

  return {
    cardRef,
    cardStyle: cardStyle as unknown as Ref<Record<string, string>>,
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
    reset,
  }
}
