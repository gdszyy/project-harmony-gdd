<template>
  <div class="share-card-container">
    <!-- 预览区域 -->
    <div class="share-preview" ref="previewRef">
      <div
        class="share-card"
        ref="cardRef"
        :style="{ background: currentTheme.bgGradient }"
      >
        <!-- 装饰粒子 -->
        <div class="card-particles">
          <div
            v-for="i in 20"
            :key="i"
            class="particle"
            :style="{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
              width: `${2 + Math.random() * 4}px`,
              height: `${2 + Math.random() * 4}px`,
              opacity: 0.1 + Math.random() * 0.3,
              animationDelay: `${Math.random() * 3}s`,
            }"
          />
        </div>

        <!-- 卡片内容 -->
        <div class="card-content" :style="{ color: currentTheme.textColor }">
          <!-- 顶部：用户信息 -->
          <div class="card-user">
            <div class="user-avatar" :style="{ borderColor: currentTheme.accentColor }">
              <img v-if="avatarUrl" :src="avatarUrl" alt="avatar" />
              <span v-else class="avatar-placeholder">{{ userName.charAt(0) }}</span>
            </div>
            <div class="user-info">
              <h2 class="user-name">{{ userName }}</h2>
              <p class="user-subtitle">的认知星图</p>
            </div>
          </div>

          <!-- 中部：迷你星图 -->
          <div class="card-starmap">
            <canvas ref="miniCanvasRef" width="300" height="200" />
          </div>

          <!-- 认知摘要 -->
          <div class="card-summary" :style="{ backgroundColor: currentTheme.cardBg }">
            <p class="summary-text" v-if="summary">
              {{ summary.insightText }}
            </p>
            <div class="summary-tags" v-if="summary">
              <span
                v-for="trait in summary.dominantTraits.slice(0, 4)"
                :key="trait"
                class="summary-tag"
                :style="{
                  backgroundColor: currentTheme.accentColor + '20',
                  color: currentTheme.accentColor,
                }"
              >
                {{ trait }}
              </span>
            </div>
            <div class="summary-stats-row" v-if="summary">
              <span class="stat">
                <strong>{{ summary.totalTags }}</strong> 认知标签
              </span>
              <span class="stat-divider">·</span>
              <span class="stat">
                <strong>{{ summary.readingDays }}</strong> 天阅读
              </span>
              <span class="stat-divider">·</span>
              <span class="stat">
                <strong>{{ summary.topDimensionLabel }}</strong> 主导
              </span>
            </div>
          </div>

          <!-- 底部：品牌 + 二维码 -->
          <div class="card-footer">
            <div class="brand-info">
              <span class="brand-name">界外 EdgeReader</span>
              <span class="brand-slogan">发现你的认知宇宙</span>
            </div>
            <div class="qr-placeholder" :style="{ borderColor: currentTheme.accentColor + '40' }">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
                <rect x="4" y="4" width="16" height="16" rx="2" :stroke="currentTheme.accentColor" stroke-width="2"/>
                <rect x="28" y="4" width="16" height="16" rx="2" :stroke="currentTheme.accentColor" stroke-width="2"/>
                <rect x="4" y="28" width="16" height="16" rx="2" :stroke="currentTheme.accentColor" stroke-width="2"/>
                <rect x="8" y="8" width="8" height="8" rx="1" :fill="currentTheme.accentColor"/>
                <rect x="32" y="8" width="8" height="8" rx="1" :fill="currentTheme.accentColor"/>
                <rect x="8" y="32" width="8" height="8" rx="1" :fill="currentTheme.accentColor"/>
                <rect x="28" y="28" width="4" height="4" :fill="currentTheme.accentColor"/>
                <rect x="36" y="28" width="8" height="4" :fill="currentTheme.accentColor"/>
                <rect x="28" y="36" width="4" height="8" :fill="currentTheme.accentColor"/>
                <rect x="36" y="40" width="8" height="4" :fill="currentTheme.accentColor"/>
                <rect x="40" y="32" width="4" height="4" :fill="currentTheme.accentColor"/>
              </svg>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 控制区域 -->
    <div class="share-controls">
      <!-- 主题选择 -->
      <div class="theme-selector">
        <button
          v-for="theme in themes"
          :key="theme.id"
          class="theme-btn"
          :class="{ active: selectedTheme === theme.id }"
          :style="{ background: theme.bgGradient }"
          @click="selectedTheme = theme.id"
          :title="theme.name"
        >
          <span class="theme-check" v-if="selectedTheme === theme.id">✓</span>
        </button>
      </div>

      <!-- 操作按钮 -->
      <div class="share-actions">
        <button class="share-btn save-btn" @click="handleSave" :disabled="isSaving">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M15.75 11.25V14.25C15.75 14.6478 15.592 15.0294 15.3107 15.3107C15.0294 15.592 14.6478 15.75 14.25 15.75H3.75C3.35218 15.75 2.97064 15.592 2.68934 15.3107C2.40804 15.0294 2.25 14.6478 2.25 14.25V11.25" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M5.25 7.5L9 11.25L12.75 7.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M9 11.25V2.25" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          {{ isSaving ? '保存中...' : '保存图片' }}
        </button>
        <button class="share-btn primary-btn" @click="handleShare" :disabled="isSharing">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M13.5 6C14.3284 6 15 5.32843 15 4.5C15 3.67157 14.3284 3 13.5 3C12.6716 3 12 3.67157 12 4.5C12 4.65736 12.0244 4.80936 12.0701 4.95198L7.04515 7.46448C6.71206 7.1080 6.23154 6.875 5.7 6.875C4.66929 6.875 3.825 7.71929 3.825 8.75C3.825 9.78071 4.66929 10.625 5.7 10.625C6.23154 10.625 6.71206 10.392 7.04515 10.0355L12.0701 12.548C12.0244 12.6906 12 12.8426 12 13C12 13.8284 12.6716 14.5 13.5 14.5C14.3284 14.5 15 13.8284 15 13C15 12.1716 14.3284 11.5 13.5 11.5C12.9685 11.5 12.4879 11.733 12.1549 12.0895L7.12985 9.57698C7.17558 9.43436 7.2 9.28236 7.2 9.125C7.2 8.96764 7.17558 8.81564 7.12985 8.67302L12.1549 6.16052C12.4879 6.517 12.9685 6.75 13.5 6.75V6Z" fill="currentColor"/>
          </svg>
          {{ isSharing ? '生成中...' : '生成分享链接' }}
        </button>
      </div>

      <!-- 关闭按钮 -->
      <button class="close-btn" @click="$emit('close')">关闭</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import type { ForceNode, ForceLink } from '@/composables/useForceGraph'
import { DIMENSION_COLORS } from '@/composables/useForceGraph'
import { SHARE_THEMES, type ShareTheme, type CognitiveSummary } from '@/types/starmap'
import { starmapApi } from '@/services/api'

const props = defineProps<{
  nodes: ForceNode[]
  links: ForceLink[]
  summary: CognitiveSummary | null
  userName: string
  avatarUrl: string
}>()

const emit = defineEmits<{
  close: []
  shared: []
}>()

// ---- 状态 ----
const cardRef = ref<HTMLElement | null>(null)
const previewRef = ref<HTMLElement | null>(null)
const miniCanvasRef = ref<HTMLCanvasElement | null>(null)
const selectedTheme = ref<ShareTheme>('cosmos')
const isSaving = ref(false)
const isSharing = ref(false)

const themes = SHARE_THEMES

const currentTheme = computed(() =>
  themes.find(t => t.id === selectedTheme.value) || themes[0]
)

// ---- 迷你星图渲染 ----
function renderMiniStarmap() {
  const canvas = miniCanvasRef.value
  if (!canvas) return

  const ctx = canvas.getContext('2d')
  if (!ctx) return

  const dpr = 2 // 高清渲染
  canvas.width = 300 * dpr
  canvas.height = 200 * dpr
  canvas.style.width = '300px'
  canvas.style.height = '200px'
  ctx.scale(dpr, dpr)

  const w = 300
  const h = 200
  const cx = w / 2
  const cy = h / 2

  // 简化布局：环形分布
  const nodePositions = props.nodes.map((node, i) => {
    const angle = (2 * Math.PI * i) / props.nodes.length - Math.PI / 2
    const distance = 30 + (1 - node.weight) * 50
    return {
      x: cx + distance * Math.cos(angle),
      y: cy + distance * Math.sin(angle),
      radius: 3 + node.weight * 8,
      color: DIMENSION_COLORS[node.dimension] || '#94A3B8',
      label: node.displayName || node.label,
    }
  })

  // 绘制连线
  const nodeMap = new Map(props.nodes.map((n, i) => [n.id, i]))
  for (const link of props.links) {
    const si = nodeMap.get(link.source)
    const ti = nodeMap.get(link.target)
    if (si === undefined || ti === undefined) continue
    const s = nodePositions[si]
    const t = nodePositions[ti]

    ctx.beginPath()
    ctx.moveTo(s.x, s.y)
    ctx.lineTo(t.x, t.y)
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.15)'
    ctx.lineWidth = 0.5
    ctx.stroke()
  }

  // 绘制节点
  for (const pos of nodePositions) {
    // 光晕
    ctx.beginPath()
    ctx.arc(pos.x, pos.y, pos.radius + 3, 0, Math.PI * 2)
    ctx.fillStyle = pos.color + '15'
    ctx.fill()

    // 节点
    ctx.beginPath()
    ctx.arc(pos.x, pos.y, pos.radius, 0, Math.PI * 2)
    ctx.fillStyle = pos.color
    ctx.fill()

    // 标签（仅大节点显示）
    if (pos.radius > 6) {
      ctx.font = '500 8px Inter, Noto Sans SC, sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'top'
      ctx.fillStyle = currentTheme.value.textColor + 'AA'
      ctx.fillText(pos.label, pos.x, pos.y + pos.radius + 4)
    }
  }
}

// ---- 保存图片 ----
async function handleSave() {
  if (!cardRef.value || isSaving.value) return
  isSaving.value = true

  try {
    // 动态导入 html2canvas
    const { default: html2canvas } = await import('html2canvas')
    const canvas = await html2canvas(cardRef.value, {
      scale: 2,
      backgroundColor: null,
      useCORS: true,
      logging: false,
    })

    // 下载图片
    const link = document.createElement('a')
    link.download = `认知星图_${props.userName}_${Date.now()}.png`
    link.href = canvas.toDataURL('image/png')
    link.click()
  } catch (err) {
    console.error('Failed to save image:', err)
    alert('保存失败，请重试')
  } finally {
    isSaving.value = false
  }
}

// ---- 生成分享链接 ----
async function handleShare() {
  if (isSharing.value) return
  isSharing.value = true

  try {
    const resp = await starmapApi.createShare({
      theme: selectedTheme.value,
      includeTimeline: false,
    })

    // 尝试使用 Web Share API
    if (navigator.share) {
      await navigator.share({
        title: `${props.userName}的认知星图`,
        text: props.summary?.insightText || '来看看我的认知宇宙',
        url: resp.shareUrl,
      })
    } else {
      // 复制链接到剪贴板
      await navigator.clipboard.writeText(resp.shareUrl)
      alert('分享链接已复制到剪贴板')
    }

    emit('shared')
  } catch (err) {
    console.error('Failed to share:', err)
    // 如果API失败，仍然可以保存图片
    alert('分享链接生成失败，你可以保存图片后手动分享')
  } finally {
    isSharing.value = false
  }
}

// ---- 监听主题变化重新渲染 ----
watch(selectedTheme, () => {
  nextTick(() => renderMiniStarmap())
})

onMounted(() => {
  nextTick(() => renderMiniStarmap())
})
</script>

<style scoped>
.share-card-container {
  display: flex;
  flex-direction: column;
  max-width: 400px;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
  border-radius: 16px;
  background: #1e293b;
}

/* ---- 预览区域 ---- */
.share-preview {
  padding: 16px;
}

.share-card {
  position: relative;
  width: 100%;
  aspect-ratio: 9 / 16;
  max-height: 500px;
  border-radius: 12px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.card-particles {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.particle {
  position: absolute;
  border-radius: 50%;
  background: white;
  animation: twinkle 3s ease-in-out infinite;
}

@keyframes twinkle {
  0%, 100% { opacity: 0.1; }
  50% { opacity: 0.5; }
}

.card-content {
  position: relative;
  z-index: 1;
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 24px 20px;
}

/* ---- 用户信息 ---- */
.card-user {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.user-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: 2px solid;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.1);
}

.user-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder {
  font-size: 20px;
  font-weight: 700;
}

.user-name {
  font-size: 18px;
  font-weight: 700;
  margin: 0;
}

.user-subtitle {
  font-size: 13px;
  opacity: 0.7;
  margin: 2px 0 0;
}

/* ---- 迷你星图 ---- */
.card-starmap {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 120px;
}

.card-starmap canvas {
  max-width: 100%;
  max-height: 100%;
}

/* ---- 认知摘要 ---- */
.card-summary {
  padding: 12px;
  border-radius: 10px;
  margin-bottom: 16px;
}

.summary-text {
  font-size: 13px;
  line-height: 1.6;
  margin: 0 0 10px;
}

.summary-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 10px;
}

.summary-tag {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 10px;
}

.summary-stats-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
  opacity: 0.8;
}

.stat strong {
  font-weight: 700;
}

.stat-divider {
  opacity: 0.4;
}

/* ---- 底部 ---- */
.card-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.brand-name {
  display: block;
  font-size: 14px;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.brand-slogan {
  display: block;
  font-size: 11px;
  opacity: 0.6;
  margin-top: 2px;
}

.qr-placeholder {
  width: 56px;
  height: 56px;
  border: 1px solid;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.05);
}

/* ---- 控制区域 ---- */
.share-controls {
  padding: 16px;
  border-top: 1px solid rgba(148, 163, 184, 0.1);
}

.theme-selector {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-bottom: 16px;
}

.theme-btn {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 2px solid transparent;
  cursor: pointer;
  position: relative;
  transition: all 0.2s;
}

.theme-btn.active {
  border-color: #818cf8;
  transform: scale(1.1);
}

.theme-check {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 14px;
  font-weight: 700;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.5);
}

.share-actions {
  display: flex;
  gap: 10px;
  margin-bottom: 12px;
}

.share-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 10px 16px;
  border: none;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.share-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.save-btn {
  background: rgba(148, 163, 184, 0.15);
  color: #e2e8f0;
}

.save-btn:hover:not(:disabled) {
  background: rgba(148, 163, 184, 0.25);
}

.primary-btn {
  background: #818cf8;
  color: white;
}

.primary-btn:hover:not(:disabled) {
  background: #6366f1;
}

.close-btn {
  width: 100%;
  padding: 10px;
  border: none;
  background: none;
  color: #64748b;
  font-size: 14px;
  cursor: pointer;
  transition: color 0.2s;
}

.close-btn:hover {
  color: #94a3b8;
}
</style>
