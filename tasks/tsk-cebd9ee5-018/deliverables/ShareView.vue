<template>
  <div class="share-view" :style="{ background: themeConfig?.bgGradient || '#0f172a' }">
    <!-- 加载状态 -->
    <div v-if="isLoading" class="loading-state">
      <div class="loading-spinner" />
      <p>加载分享内容...</p>
    </div>

    <!-- 错误状态 -->
    <div v-else-if="error" class="error-state">
      <h2>{{ error }}</h2>
      <p>分享链接可能已过期或不存在</p>
      <router-link to="/" class="home-link">返回首页</router-link>
    </div>

    <!-- 分享内容 -->
    <div v-else class="share-content" :style="{ color: themeConfig?.textColor || '#e2e8f0' }">
      <!-- 星图快照 -->
      <div class="share-starmap">
        <canvas ref="canvasRef" width="600" height="400" />
      </div>

      <!-- 认知信息 -->
      <div class="share-info" :style="{ backgroundColor: themeConfig?.cardBg || 'rgba(15,23,42,0.85)' }">
        <h2 class="share-title">认知星图</h2>
        <p class="share-stats">
          {{ shareData?.snapshot?.nodes?.length || 0 }} 个认知标签 · {{ shareData?.viewCount || 0 }} 次查看
        </p>
      </div>

      <!-- CTA -->
      <div class="share-cta">
        <p>发现你的认知宇宙</p>
        <router-link to="/" class="cta-btn">开始探索 EdgeReader</router-link>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { starmapApi } from '@/services/api'
import { SHARE_THEMES, type ShareThemeConfig } from '@/types/starmap'
import { DIMENSION_COLORS } from '@/composables/useForceGraph'

const route = useRoute()
const isLoading = ref(true)
const error = ref<string | null>(null)
const shareData = ref<any>(null)
const themeConfig = ref<ShareThemeConfig | null>(null)
const canvasRef = ref<HTMLCanvasElement | null>(null)

async function loadShare() {
  const shareId = route.params.shareId as string
  if (!shareId) {
    error.value = '无效的分享链接'
    isLoading.value = false
    return
  }

  try {
    const resp = await starmapApi.getShare(shareId)
    shareData.value = resp
    themeConfig.value = SHARE_THEMES.find(t => t.id === resp.theme) || SHARE_THEMES[0]
    renderStarmap(resp.snapshot)
  } catch (err: any) {
    error.value = '分享内容不存在或已过期'
  } finally {
    isLoading.value = false
  }
}

function renderStarmap(snapshot: any) {
  if (!canvasRef.value || !snapshot?.nodes) return
  const canvas = canvasRef.value
  const ctx = canvas.getContext('2d')
  if (!ctx) return

  const dpr = 2
  canvas.width = 600 * dpr
  canvas.height = 400 * dpr
  canvas.style.width = '100%'
  canvas.style.maxWidth = '600px'
  canvas.style.height = 'auto'
  ctx.scale(dpr, dpr)

  const w = 600, h = 400, cx = w / 2, cy = h / 2
  const nodes = snapshot.nodes || []

  // 环形布局
  const positions = nodes.map((n: any, i: number) => {
    const angle = (2 * Math.PI * i) / nodes.length - Math.PI / 2
    const dist = 60 + (1 - (n.weight || 0.5)) * 100
    return {
      x: cx + dist * Math.cos(angle),
      y: cy + dist * Math.sin(angle),
      radius: 4 + (n.weight || 0.5) * 12,
      color: DIMENSION_COLORS[n.dimension as keyof typeof DIMENSION_COLORS] || '#94A3B8',
      label: n.tagDisplayName || n.tagName,
    }
  })

  // 连线
  const edges = snapshot.edges || []
  const nodeMap = new Map(nodes.map((n: any, i: number) => [n.id || n.tagName, i]))
  for (const edge of edges) {
    const si = nodeMap.get(edge.source)
    const ti = nodeMap.get(edge.target)
    if (si === undefined || ti === undefined) continue
    ctx.beginPath()
    ctx.moveTo(positions[si].x, positions[si].y)
    ctx.lineTo(positions[ti].x, positions[ti].y)
    ctx.strokeStyle = 'rgba(148,163,184,0.12)'
    ctx.lineWidth = 0.5
    ctx.stroke()
  }

  // 节点
  for (const pos of positions) {
    ctx.beginPath()
    ctx.arc(pos.x, pos.y, pos.radius + 3, 0, Math.PI * 2)
    ctx.fillStyle = pos.color + '15'
    ctx.fill()

    ctx.beginPath()
    ctx.arc(pos.x, pos.y, pos.radius, 0, Math.PI * 2)
    ctx.fillStyle = pos.color
    ctx.fill()

    if (pos.radius > 8) {
      ctx.font = '500 10px Inter, Noto Sans SC, sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'top'
      ctx.fillStyle = themeConfig.value?.textColor || '#e2e8f0'
      ctx.globalAlpha = 0.7
      ctx.fillText(pos.label, pos.x, pos.y + pos.radius + 5)
      ctx.globalAlpha = 1
    }
  }
}

onMounted(() => {
  loadShare()
})
</script>

<style scoped>
.share-view {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.loading-state,
.error-state {
  text-align: center;
  color: #94a3b8;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(148,163,184,0.2);
  border-top-color: #818cf8;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 16px;
}

@keyframes spin { to { transform: rotate(360deg); } }

.home-link {
  display: inline-block;
  margin-top: 16px;
  padding: 8px 20px;
  background: #818cf8;
  color: white;
  border-radius: 8px;
  text-decoration: none;
}

.share-content {
  max-width: 600px;
  width: 100%;
  text-align: center;
}

.share-starmap {
  margin-bottom: 20px;
}

.share-starmap canvas {
  border-radius: 12px;
}

.share-info {
  padding: 20px;
  border-radius: 12px;
  margin-bottom: 20px;
}

.share-title {
  font-size: 20px;
  font-weight: 700;
  margin: 0 0 8px;
}

.share-stats {
  font-size: 13px;
  opacity: 0.7;
  margin: 0;
}

.share-cta {
  margin-top: 24px;
}

.share-cta p {
  font-size: 14px;
  opacity: 0.6;
  margin-bottom: 12px;
}

.cta-btn {
  display: inline-block;
  padding: 12px 32px;
  background: #818cf8;
  color: white;
  border-radius: 10px;
  text-decoration: none;
  font-weight: 600;
  transition: background 0.2s;
}

.cta-btn:hover {
  background: #6366f1;
}
</style>
