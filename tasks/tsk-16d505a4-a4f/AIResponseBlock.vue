<template>
  <div class="ai-response-block" :class="{ 'is-streaming': isStreaming }">
    <!-- 三步走阶段块 -->
    <TransitionGroup name="phase-enter" tag="div" class="phases-container">
      <div
        v-for="(phase, index) in parsedPhases"
        :key="phase.type + '-' + index"
        class="phase-block"
        :class="[
          `phase-${phase.type}`,
          {
            'phase-active': isStreaming && index === parsedPhases.length - 1,
            'phase-complete': !isStreaming || index < parsedPhases.length - 1,
          },
        ]"
      >
        <!-- 阶段标题栏 -->
        <div class="phase-header">
          <span class="phase-icon" v-html="phaseConfig[phase.type].icon"></span>
          <span class="phase-label">{{ phaseConfig[phase.type].label }}</span>
          <span
            v-if="isStreaming && index === parsedPhases.length - 1"
            class="phase-streaming-dot"
          ></span>
        </div>

        <!-- 阶段内容 -->
        <div
          class="phase-content"
          :class="{ 'typing-cursor': isStreaming && index === parsedPhases.length - 1 }"
          v-html="renderMarkdown(phase.content)"
        ></div>
      </div>
    </TransitionGroup>

    <!-- 如果内容不包含三步走标记，回退为普通渲染 -->
    <div
      v-if="parsedPhases.length === 0 && content"
      class="phase-fallback"
      :class="{ 'typing-cursor': isStreaming }"
      v-html="renderMarkdown(content)"
    ></div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { marked } from 'marked'

// ---- Props ----
const props = defineProps<{
  /** AI 回复的原始文本内容 */
  content: string
  /** 是否正在流式输出 */
  isStreaming?: boolean
}>()

// ---- 阶段类型定义 ----
type PhaseType = 'resonance' | 'validation' | 'expansion'

interface ParsedPhase {
  type: PhaseType
  content: string
}

// ---- 阶段配置（图标 + 标签 + 色调） ----
const phaseConfig: Record<PhaseType, { label: string; icon: string }> = {
  resonance: {
    label: '共鸣',
    icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="none">
      <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
    </svg>`,
  },
  validation: {
    label: '验证',
    icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
      <polyline points="20 6 9 17 4 12"/>
    </svg>`,
  },
  expansion: {
    label: '拓展',
    icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="none">
      <path d="M9 21c0 .55.45 1 1 1h4c.55 0 1-.45 1-1v-1H9v1zm3-19C8.14 2 5 5.14 5 9c0 2.38 1.19 4.47 3 5.74V17c0 .55.45 1 1 1h6c.55 0 1-.45 1-1v-2.26c1.81-1.27 3-3.36 3-5.74 0-3.86-3.14-7-7-7z"/>
    </svg>`,
  },
}

// ---- 标记到阶段类型的映射 ----
const markerMap: Record<string, PhaseType> = {
  '共鸣': 'resonance',
  '验证': 'validation',
  '拓展': 'expansion',
}

// ---- 解析三步走标记 ----
const parsedPhases = computed<ParsedPhase[]>(() => {
  const text = props.content
  if (!text) return []

  // 正则匹配 [共鸣]、[验证]、[拓展] 标记
  const markerRegex = /\[(共鸣|验证|拓展)\]/g
  const markers: { type: PhaseType; index: number; length: number }[] = []

  let match: RegExpExecArray | null
  while ((match = markerRegex.exec(text)) !== null) {
    const phaseType = markerMap[match[1]]
    if (phaseType) {
      markers.push({
        type: phaseType,
        index: match.index,
        length: match[0].length,
      })
    }
  }

  // 如果没有找到任何标记，返回空数组（使用 fallback 渲染）
  if (markers.length === 0) return []

  // 按位置切分内容
  const phases: ParsedPhase[] = []
  for (let i = 0; i < markers.length; i++) {
    const start = markers[i].index + markers[i].length
    const end = i + 1 < markers.length ? markers[i + 1].index : text.length
    const content = text.slice(start, end).trim()

    if (content || props.isStreaming) {
      phases.push({
        type: markers[i].type,
        content,
      })
    }
  }

  return phases
})

// ---- Markdown 渲染 ----
function renderMarkdown(content: string): string {
  if (!content) return ''
  try {
    return marked.parse(content, { async: false }) as string
  } catch {
    return content
  }
}
</script>

<style scoped>
/* ============================================================
   AI 回复三步走视觉区分组件样式
   ============================================================ */

.ai-response-block {
  display: flex;
  flex-direction: column;
  gap: 0;
  width: 100%;
}

.phases-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

/* ---- 阶段块通用样式 ---- */
.phase-block {
  border-radius: 10px;
  padding: 10px 12px;
  border-left: 3px solid transparent;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
}

.phase-block::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  opacity: 0;
  transition: opacity 0.3s ease;
  pointer-events: none;
  border-radius: inherit;
}

.phase-active::before {
  opacity: 1;
}

/* ---- 共鸣阶段：温暖色调 ---- */
.phase-resonance {
  background: oklch(0.97 0.02 30 / 0.6);
  border-left-color: oklch(0.65 0.18 25);
}

.phase-resonance .phase-header {
  color: oklch(0.50 0.15 25);
}

.phase-resonance .phase-icon {
  color: oklch(0.60 0.20 25);
}

.phase-resonance::before {
  background: linear-gradient(
    90deg,
    oklch(0.95 0.04 30 / 0.3) 0%,
    transparent 100%
  );
}

/* ---- 验证阶段：理性色调 ---- */
.phase-validation {
  background: oklch(0.97 0.02 250 / 0.5);
  border-left-color: oklch(0.55 0.15 250);
}

.phase-validation .phase-header {
  color: oklch(0.45 0.12 250);
}

.phase-validation .phase-icon {
  color: oklch(0.55 0.18 250);
}

.phase-validation::before {
  background: linear-gradient(
    90deg,
    oklch(0.95 0.03 250 / 0.3) 0%,
    transparent 100%
  );
}

/* ---- 拓展阶段：探索色调 ---- */
.phase-expansion {
  background: oklch(0.97 0.03 140 / 0.5);
  border-left-color: oklch(0.55 0.15 140);
}

.phase-expansion .phase-header {
  color: oklch(0.45 0.12 140);
}

.phase-expansion .phase-icon {
  color: oklch(0.55 0.18 140);
}

.phase-expansion::before {
  background: linear-gradient(
    90deg,
    oklch(0.95 0.04 140 / 0.3) 0%,
    transparent 100%
  );
}

/* ---- 阶段标题栏 ---- */
.phase-header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 6px;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.5px;
  user-select: none;
}

.phase-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  flex-shrink: 0;
}

.phase-resonance .phase-icon {
  background: oklch(0.90 0.06 25 / 0.5);
}

.phase-validation .phase-icon {
  background: oklch(0.90 0.04 250 / 0.5);
}

.phase-expansion .phase-icon {
  background: oklch(0.90 0.05 140 / 0.5);
}

.phase-label {
  text-transform: uppercase;
  font-family: var(--font-sans, system-ui, sans-serif);
}

/* ---- 流式输出指示点 ---- */
.phase-streaming-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  animation: pulse-dot 1.2s ease-in-out infinite;
  margin-left: 4px;
}

.phase-resonance .phase-streaming-dot {
  background: oklch(0.60 0.20 25);
}

.phase-validation .phase-streaming-dot {
  background: oklch(0.55 0.18 250);
}

.phase-expansion .phase-streaming-dot {
  background: oklch(0.55 0.18 140);
}

@keyframes pulse-dot {
  0%, 100% {
    opacity: 0.4;
    transform: scale(0.8);
  }
  50% {
    opacity: 1;
    transform: scale(1.2);
  }
}

/* ---- 阶段内容 ---- */
.phase-content {
  font-size: 14px;
  line-height: 1.7;
  color: var(--color-fg, oklch(0.20 0.02 250));
  word-break: break-word;
}

.phase-content :deep(p) {
  margin: 0;
}

.phase-content :deep(p + p) {
  margin-top: 6px;
}

.phase-content :deep(strong) {
  font-weight: 600;
}

.phase-content :deep(em) {
  font-style: italic;
}

.phase-content :deep(a) {
  color: oklch(0.55 0.15 250);
  text-decoration: underline;
  text-underline-offset: 2px;
}

/* ---- 打字光标效果 ---- */
.typing-cursor::after {
  content: '';
  display: inline-block;
  width: 2px;
  height: 1em;
  background: var(--color-fg, oklch(0.20 0.02 250));
  margin-left: 2px;
  vertical-align: text-bottom;
  animation: blink-cursor 0.8s step-end infinite;
}

@keyframes blink-cursor {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

/* ---- Fallback 普通渲染 ---- */
.phase-fallback {
  font-size: 14px;
  line-height: 1.7;
  color: var(--color-fg, oklch(0.20 0.02 250));
  word-break: break-word;
}

.phase-fallback :deep(p) {
  margin: 0 0 6px;
}

/* ---- TransitionGroup 动画 ---- */
.phase-enter-enter-active {
  animation: phase-slide-in 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.phase-enter-leave-active {
  animation: phase-slide-out 0.3s ease-in;
}

@keyframes phase-slide-in {
  0% {
    opacity: 0;
    transform: translateY(12px) scale(0.97);
    max-height: 0;
  }
  100% {
    opacity: 1;
    transform: translateY(0) scale(1);
    max-height: 500px;
  }
}

@keyframes phase-slide-out {
  0% {
    opacity: 1;
    transform: translateY(0);
  }
  100% {
    opacity: 0;
    transform: translateY(-8px);
  }
}

/* ---- 阶段完成时的微妙过渡 ---- */
.phase-complete {
  opacity: 1;
}

.phase-active {
  box-shadow: 0 1px 8px oklch(0.50 0.05 250 / 0.08);
}

/* ---- 暗色模式适配 ---- */
@media (prefers-color-scheme: dark) {
  .phase-resonance {
    background: oklch(0.25 0.03 25 / 0.4);
    border-left-color: oklch(0.70 0.15 25);
  }
  .phase-resonance .phase-header { color: oklch(0.80 0.12 25); }
  .phase-resonance .phase-icon { color: oklch(0.75 0.15 25); background: oklch(0.35 0.06 25 / 0.5); }

  .phase-validation {
    background: oklch(0.25 0.02 250 / 0.4);
    border-left-color: oklch(0.70 0.12 250);
  }
  .phase-validation .phase-header { color: oklch(0.80 0.10 250); }
  .phase-validation .phase-icon { color: oklch(0.75 0.12 250); background: oklch(0.35 0.04 250 / 0.5); }

  .phase-expansion {
    background: oklch(0.25 0.03 140 / 0.4);
    border-left-color: oklch(0.70 0.12 140);
  }
  .phase-expansion .phase-header { color: oklch(0.80 0.10 140); }
  .phase-expansion .phase-icon { color: oklch(0.75 0.12 140); background: oklch(0.35 0.05 140 / 0.5); }

  .phase-content { color: oklch(0.88 0.01 250); }
  .phase-fallback { color: oklch(0.88 0.01 250); }
  .typing-cursor::after { background: oklch(0.88 0.01 250); }
}

/* ---- 响应式适配 ---- */
@media (max-width: 640px) {
  .phase-block {
    padding: 8px 10px;
    border-radius: 8px;
  }

  .phase-header {
    font-size: 11px;
  }

  .phase-content {
    font-size: 13px;
  }
}
</style>
