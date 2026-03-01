<template>
  <div class="starmap-view" ref="viewRef">
    <!-- 顶部导航栏 -->
    <header class="starmap-header">
      <button class="back-btn" @click="$router.back()">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M12.5 15L7.5 10L12.5 5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
      <h1 class="header-title">认知星图</h1>
      <div class="header-actions">
        <button class="action-btn" @click="showShareModal = true" title="分享">
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path d="M15 7C16.1046 7 17 6.10457 17 5C17 3.89543 16.1046 3 15 3C13.8954 3 13 3.89543 13 5C13 5.20981 13.0326 5.41249 13.0935 5.60264L7.72687 8.28598C7.28275 7.81067 6.67539 7.5 6 7.5C4.61929 7.5 3.5 8.61929 3.5 10C3.5 11.3807 4.61929 12.5 6 12.5C6.67539 12.5 7.28275 12.1893 7.72687 11.714L13.0935 14.3974C13.0326 14.5875 13 14.7902 13 15C13 16.1046 13.8954 17 15 17C16.1046 17 17 16.1046 17 15C17 13.8954 16.1046 13 15 13C14.3246 13 13.7173 13.3107 13.2731 13.786L7.90649 11.1026C7.96742 10.9125 8 10.7098 8 10.5C8 10.2902 7.96742 10.0875 7.90649 9.89736L13.2731 7.21402C13.7173 7.68933 14.3246 8 15 8V7Z" fill="currentColor"/>
          </svg>
        </button>
        <button class="action-btn" @click="handleFitView" title="适应视图">
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path d="M3 7V3H7M13 3H17V7M17 13V17H13M7 17H3V13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>
      </div>
    </header>

    <!-- 维度图例 -->
    <div class="dimension-legend">
      <div
        v-for="(label, dim) in dimensionLabels"
        :key="dim"
        class="legend-item"
        :class="{ active: !filteredDimensions.has(dim) }"
        @click="toggleDimension(dim)"
      >
        <span class="legend-dot" :style="{ backgroundColor: dimensionColors[dim] }" />
        <span class="legend-text">{{ label }}</span>
      </div>
    </div>

    <!-- Canvas 星图 -->
    <div class="starmap-canvas-wrapper" ref="canvasWrapper">
      <canvas ref="canvasRef" class="starmap-canvas" />

      <!-- 加载状态 -->
      <div v-if="isLoading" class="loading-overlay">
        <div class="loading-spinner" />
        <p class="loading-text">正在构建你的认知宇宙...</p>
      </div>

      <!-- 空状态 -->
      <div v-else-if="!isLoading && nodes.length === 0" class="empty-state">
        <div class="empty-icon">✨</div>
        <p class="empty-title">你的认知星图尚未形成</p>
        <p class="empty-desc">继续阅读和思考，标签会逐渐点亮星空</p>
      </div>
    </div>

    <!-- 时间轴控制器 -->
    <div v-if="timeline.length > 1" class="timeline-control">
      <button
        class="timeline-btn"
        :disabled="currentTimeIndex <= 0"
        @click="currentTimeIndex = Math.max(0, currentTimeIndex - 1)"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <path d="M10 12L6 8L10 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
      <div class="timeline-track">
        <div
          v-for="(snap, i) in timeline"
          :key="snap.timestamp"
          class="timeline-dot"
          :class="{ active: i === currentTimeIndex }"
          @click="currentTimeIndex = i"
        >
          <span class="timeline-label">{{ snap.label }}</span>
        </div>
      </div>
      <button
        class="timeline-btn"
        :disabled="currentTimeIndex >= timeline.length - 1"
        @click="currentTimeIndex = Math.min(timeline.length - 1, currentTimeIndex + 1)"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <path d="M6 4L10 8L6 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
    </div>

    <!-- 认知摘要面板 -->
    <div v-if="summary" class="summary-panel" :class="{ expanded: showSummary }">
      <button class="summary-toggle" @click="showSummary = !showSummary">
        <span class="summary-toggle-text">{{ showSummary ? '收起' : '认知画像' }}</span>
        <svg
          width="16" height="16" viewBox="0 0 16 16" fill="none"
          :style="{ transform: showSummary ? 'rotate(180deg)' : '' }"
        >
          <path d="M4 6L8 10L12 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
      <div v-if="showSummary" class="summary-content">
        <p class="summary-insight">{{ summary.insightText }}</p>
        <div class="summary-stats">
          <div class="stat-item">
            <span class="stat-value">{{ summary.totalTags }}</span>
            <span class="stat-label">认知标签</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ summary.readingDays }}</span>
            <span class="stat-label">阅读天数</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ summary.topDimensionLabel }}</span>
            <span class="stat-label">主导维度</span>
          </div>
        </div>
        <div v-if="summary.dominantTraits.length" class="summary-traits">
          <span class="trait-label">核心特质：</span>
          <span v-for="trait in summary.dominantTraits" :key="trait" class="trait-tag">
            {{ trait }}
          </span>
        </div>
        <div v-if="summary.recentGrowth.length" class="summary-growth">
          <span class="trait-label">近期成长：</span>
          <span v-for="g in summary.recentGrowth" :key="g" class="growth-tag">
            {{ g }}
          </span>
        </div>
      </div>
    </div>

    <!-- 节点详情弹窗 -->
    <Transition name="slide-up">
      <div v-if="selectedNodeDetail" class="node-detail-panel">
        <div class="detail-header">
          <div class="detail-dot" :style="{ backgroundColor: selectedNodeDetail.color }" />
          <h3 class="detail-title">{{ selectedNodeDetail.displayName || selectedNodeDetail.label }}</h3>
          <button class="detail-close" @click="selectedNodeDetail = null">
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M4 4L12 12M12 4L4 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
            </svg>
          </button>
        </div>
        <div class="detail-body">
          <div class="detail-row">
            <span class="detail-label">维度</span>
            <span class="detail-value">{{ dimensionLabels[selectedNodeDetail.dimension] }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">权重</span>
            <div class="detail-bar-wrapper">
              <div class="detail-bar" :style="{ width: `${selectedNodeDetail.weight * 100}%`, backgroundColor: selectedNodeDetail.color }" />
            </div>
            <span class="detail-value">{{ (selectedNodeDetail.weight * 100).toFixed(0) }}%</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">置信度</span>
            <span class="detail-value">{{ (selectedNodeDetail.confidence * 100).toFixed(0) }}%</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">证据数</span>
            <span class="detail-value">{{ selectedNodeDetail.evidenceCount }} 条碎碎念</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">首次发现</span>
            <span class="detail-value">{{ formatDate(selectedNodeDetail.firstDetectedAt) }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">最近强化</span>
            <span class="detail-value">{{ formatDate(selectedNodeDetail.lastReinforcedAt) }}</span>
          </div>
        </div>
      </div>
    </Transition>

    <!-- 分享弹窗 -->
    <Transition name="fade">
      <div v-if="showShareModal" class="share-modal-overlay" @click.self="showShareModal = false">
        <ShareCard
          :nodes="nodes"
          :links="forceLinks"
          :summary="summary"
          :user-name="userName"
          :avatar-url="avatarUrl"
          @close="showShareModal = false"
          @shared="handleShared"
        />
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useForceGraph, DIMENSION_COLORS, DIMENSION_LABELS, type ForceNode, type ForceLink, type CognitiveDimension } from '@/composables/useForceGraph'
import { starmapApi } from '@/services/api'
import type { StarmapResponse, StarmapSnapshot, CognitiveSummary } from '@/types/starmap'
import ShareCard from '@/components/starmap/ShareCard.vue'

// ---- 状态 ----
const viewRef = ref<HTMLElement | null>(null)
const canvasRef = ref<HTMLCanvasElement | null>(null)
const canvasWrapper = ref<HTMLElement | null>(null)

const isLoading = ref(true)
const showSummary = ref(false)
const showShareModal = ref(false)
const currentTimeIndex = ref(-1)
const filteredDimensions = ref(new Set<CognitiveDimension>())

const starmapData = ref<StarmapResponse | null>(null)
const selectedNodeDetail = ref<ForceNode | null>(null)

// ---- 计算属性 ----
const dimensionColors = DIMENSION_COLORS
const dimensionLabels = DIMENSION_LABELS

const userName = computed(() => starmapData.value?.userName || '匿名用户')
const avatarUrl = computed(() => starmapData.value?.avatarUrl || '')

const summary = computed<CognitiveSummary | null>(() => starmapData.value?.summary || null)

const timeline = computed(() => starmapData.value?.timeline || [])

const currentSnapshot = computed<StarmapSnapshot | null>(() => {
  if (!starmapData.value) return null
  if (currentTimeIndex.value >= 0 && currentTimeIndex.value < timeline.value.length) {
    return timeline.value[currentTimeIndex.value]
  }
  return starmapData.value.currentSnapshot
})

const nodes = ref<ForceNode[]>([])
const forceLinks = ref<ForceLink[]>([])

const canvasWidth = ref(800)
const canvasHeight = ref(600)

// ---- 力导向图 ----
const {
  selectedNode,
  hoveredNode,
  resetView,
  fitView,
  reheat,
} = useForceGraph({
  canvasRef,
  nodes,
  links: forceLinks,
  width: canvasWidth,
  height: canvasHeight,
  onNodeClick: (node) => {
    selectedNodeDetail.value = node
  },
  onNodeHover: (_node) => {
    // hover 效果由引擎内部处理
  },
})

// ---- 方法 ----
function toggleDimension(dim: CognitiveDimension) {
  if (filteredDimensions.value.has(dim)) {
    filteredDimensions.value.delete(dim)
  } else {
    filteredDimensions.value.add(dim)
  }
  updateGraphFromSnapshot()
}

function updateGraphFromSnapshot() {
  const snap = currentSnapshot.value
  if (!snap) return

  const filteredNodes = snap.nodes
    .filter(n => !filteredDimensions.value.has(n.dimension))
    .map(n => ({
      id: n.id || n.tagName,
      label: n.tagName,
      displayName: n.tagDisplayName,
      weight: n.weight,
      dimension: n.dimension,
      evidenceCount: n.evidenceCount,
      confidence: n.confidence,
      firstDetectedAt: n.firstDetectedAt,
      lastReinforcedAt: n.lastReinforcedAt,
      x: canvasWidth.value / 2 + (Math.random() - 0.5) * canvasWidth.value * 0.5,
      y: canvasHeight.value / 2 + (Math.random() - 0.5) * canvasHeight.value * 0.5,
      vx: 0,
      vy: 0,
      radius: 8 + n.weight * 20,
      color: DIMENSION_COLORS[n.dimension] || '#94A3B8',
      isNew: Date.now() - n.lastReinforcedAt < 7 * 24 * 3600 * 1000,
    } as ForceNode))

  const nodeIds = new Set(filteredNodes.map(n => n.id))
  const filteredEdges = snap.edges
    .filter(e => nodeIds.has(e.source) && nodeIds.has(e.target))
    .map(e => ({
      source: e.source,
      target: e.target,
      distance: e.distance,
      strength: 1 - e.distance * 0.5,
    } as ForceLink))

  nodes.value = filteredNodes
  forceLinks.value = filteredEdges

  nextTick(() => reheat())
}

function handleFitView() {
  fitView()
}

function handleShared() {
  showShareModal.value = false
}

function formatDate(ts: number): string {
  if (!ts) return '-'
  const d = new Date(ts)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// ---- 尺寸监听 ----
let resizeObserver: ResizeObserver | null = null

function updateCanvasSize() {
  if (canvasWrapper.value) {
    canvasWidth.value = canvasWrapper.value.clientWidth
    canvasHeight.value = canvasWrapper.value.clientHeight
  }
}

// ---- 数据加载 ----
async function loadStarmap() {
  isLoading.value = true
  try {
    const resp = await starmapApi.getStarmap('me')
    starmapData.value = resp
    if (resp.timeline.length > 0) {
      currentTimeIndex.value = resp.timeline.length - 1
    }
    updateGraphFromSnapshot()
  } catch (err) {
    console.error('Failed to load starmap:', err)
    // 使用模拟数据进行演示
    loadMockData()
  } finally {
    isLoading.value = false
  }
}

function loadMockData() {
  const now = Date.now()
  const dimensions: CognitiveDimension[] = [
    'understanding_preference', 'focus_domain', 'emotional_tendency', 'thinking_pattern'
  ]
  const tagNames = [
    // 理解偏好
    { name: 'analogy', display: '类比思维', dim: 'understanding_preference' as CognitiveDimension, w: 0.85 },
    { name: 'systems_thinking', display: '系统思维', dim: 'understanding_preference' as CognitiveDimension, w: 0.72 },
    { name: 'deduction', display: '演绎推理', dim: 'understanding_preference' as CognitiveDimension, w: 0.65 },
    { name: 'narrative', display: '叙事思维', dim: 'understanding_preference' as CognitiveDimension, w: 0.45 },
    { name: 'contrarian', display: '逆向思维', dim: 'understanding_preference' as CognitiveDimension, w: 0.38 },
    { name: 'quantitative', display: '量化思维', dim: 'understanding_preference' as CognitiveDimension, w: 0.55 },
    { name: 'induction', display: '归纳总结', dim: 'understanding_preference' as CognitiveDimension, w: 0.60 },
    { name: 'metaphorical', display: '隐喻偏好', dim: 'understanding_preference' as CognitiveDimension, w: 0.30 },
    // 关注域
    { name: 'tech_innovation', display: '技术创新', dim: 'focus_domain' as CognitiveDimension, w: 0.90 },
    { name: 'mechanism_analysis', display: '机制分析', dim: 'focus_domain' as CognitiveDimension, w: 0.78 },
    { name: 'decision_making', display: '决策判断', dim: 'focus_domain' as CognitiveDimension, w: 0.68 },
    { name: 'trend_prediction', display: '趋势预测', dim: 'focus_domain' as CognitiveDimension, w: 0.55 },
    { name: 'execution', display: '落地执行', dim: 'focus_domain' as CognitiveDimension, w: 0.48 },
    { name: 'humanistic_care', display: '人文关怀', dim: 'focus_domain' as CognitiveDimension, w: 0.35 },
    { name: 'creative_expression', display: '创意表达', dim: 'focus_domain' as CognitiveDimension, w: 0.42 },
    { name: 'historical_perspective', display: '历史纵深', dim: 'focus_domain' as CognitiveDimension, w: 0.28 },
    // 情绪倾向
    { name: 'curiosity', display: '好奇心', dim: 'emotional_tendency' as CognitiveDimension, w: 0.82 },
    { name: 'skepticism', display: '质疑精神', dim: 'emotional_tendency' as CognitiveDimension, w: 0.58 },
    { name: 'empathy', display: '共情力', dim: 'emotional_tendency' as CognitiveDimension, w: 0.45 },
    { name: 'enthusiasm', display: '热忱', dim: 'emotional_tendency' as CognitiveDimension, w: 0.62 },
    { name: 'contemplation', display: '沉思', dim: 'emotional_tendency' as CognitiveDimension, w: 0.50 },
    // 思维方式
    { name: 'first_principles', display: '第一性原理', dim: 'thinking_pattern' as CognitiveDimension, w: 0.75 },
    { name: 'cross_domain', display: '跨域连接', dim: 'thinking_pattern' as CognitiveDimension, w: 0.70 },
    { name: 'abstraction', display: '抽象提炼', dim: 'thinking_pattern' as CognitiveDimension, w: 0.60 },
    { name: 'pattern_recognition', display: '模式识别', dim: 'thinking_pattern' as CognitiveDimension, w: 0.55 },
    { name: 'iterative', display: '迭代思维', dim: 'thinking_pattern' as CognitiveDimension, w: 0.48 },
  ]

  const mockNodes = tagNames.map((t, i) => ({
    id: t.name,
    tagName: t.name,
    tagDisplayName: t.display,
    dimension: t.dim,
    weight: t.w,
    confidence: 0.3 + Math.random() * 0.6,
    evidenceCount: Math.floor(3 + Math.random() * 20),
    firstDetectedAt: now - (30 - i) * 86400000,
    lastReinforcedAt: now - Math.floor(Math.random() * 7) * 86400000,
    decayRate: 0.01,
  }))

  // 生成连线：同维度内连接 + 跨维度关联
  const mockEdges: { source: string; target: string; distance: number; type: 'same_dimension' | 'cross_dimension' | 'adjacency' }[] = []
  const byDim = new Map<string, typeof mockNodes>()
  for (const n of mockNodes) {
    if (!byDim.has(n.dimension)) byDim.set(n.dimension, [])
    byDim.get(n.dimension)!.push(n)
  }

  // 同维度内连接
  for (const [_dim, dimNodes] of byDim) {
    for (let i = 0; i < dimNodes.length; i++) {
      for (let j = i + 1; j < dimNodes.length; j++) {
        if (Math.random() < 0.5) {
          mockEdges.push({
            source: dimNodes[i].id,
            target: dimNodes[j].id,
            distance: 0.2 + Math.random() * 0.3,
            type: 'same_dimension',
          })
        }
      }
    }
  }

  // 跨维度关联
  const crossLinks = [
    ['analogy', 'cross_domain'], ['systems_thinking', 'first_principles'],
    ['tech_innovation', 'curiosity'], ['mechanism_analysis', 'abstraction'],
    ['decision_making', 'quantitative'], ['deduction', 'pattern_recognition'],
    ['narrative', 'empathy'], ['trend_prediction', 'skepticism'],
    ['creative_expression', 'enthusiasm'], ['execution', 'iterative'],
  ]
  for (const [s, t] of crossLinks) {
    mockEdges.push({ source: s, target: t, distance: 0.4 + Math.random() * 0.3, type: 'cross_dimension' })
  }

  // 生成时间线快照
  const snapshots: StarmapSnapshot[] = []
  for (let w = 4; w >= 0; w--) {
    const snapTs = now - w * 7 * 86400000
    const snapNodes = mockNodes
      .filter((_n, i) => i < mockNodes.length - w * 3)
      .map(n => ({ ...n }))
    const snapNodeIds = new Set(snapNodes.map(n => n.id))
    const snapEdges = mockEdges.filter(e => snapNodeIds.has(e.source) && snapNodeIds.has(e.target))
    snapshots.push({
      timestamp: snapTs,
      label: `第${5 - w}周`,
      nodes: snapNodes,
      edges: snapEdges,
    })
  }

  starmapData.value = {
    userId: 1,
    userName: '探索者',
    avatarUrl: '',
    currentSnapshot: snapshots[snapshots.length - 1],
    timeline: snapshots,
    summary: {
      totalTags: mockNodes.length,
      topDimension: 'understanding_preference',
      topDimensionLabel: '理解偏好',
      dominantTraits: ['类比思维', '系统思维', '技术创新'],
      recentGrowth: ['第一性原理', '跨域连接'],
      readingDays: 28,
      insightText: '你是一位善于类比思考的技术探索者，擅长从不同领域中发现共通的底层规律。',
    },
    generatedAt: now,
  }

  currentTimeIndex.value = snapshots.length - 1
  updateGraphFromSnapshot()
}

// ---- 时间轴切换 ----
watch(currentTimeIndex, () => {
  updateGraphFromSnapshot()
})

// ---- 生命周期 ----
onMounted(async () => {
  updateCanvasSize()

  resizeObserver = new ResizeObserver(() => {
    updateCanvasSize()
  })
  if (canvasWrapper.value) {
    resizeObserver.observe(canvasWrapper.value)
  }

  await nextTick()
  loadStarmap()
})

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect()
  }
})
</script>

<style scoped>
.starmap-view {
  position: relative;
  width: 100%;
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: #0f172a;
  color: #e2e8f0;
  overflow: hidden;
}

/* ---- 顶部导航 ---- */
.starmap-header {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background: rgba(15, 23, 42, 0.9);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid rgba(148, 163, 184, 0.1);
  z-index: 10;
}

.back-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border: none;
  background: rgba(148, 163, 184, 0.1);
  border-radius: 8px;
  color: #94a3b8;
  cursor: pointer;
  transition: all 0.2s;
}

.back-btn:hover {
  background: rgba(148, 163, 184, 0.2);
  color: #e2e8f0;
}

.header-title {
  flex: 1;
  text-align: center;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0.02em;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border: none;
  background: rgba(148, 163, 184, 0.1);
  border-radius: 8px;
  color: #94a3b8;
  cursor: pointer;
  transition: all 0.2s;
}

.action-btn:hover {
  background: rgba(148, 163, 184, 0.2);
  color: #e2e8f0;
}

/* ---- 维度图例 ---- */
.dimension-legend {
  display: flex;
  justify-content: center;
  gap: 16px;
  padding: 8px 16px;
  background: rgba(15, 23, 42, 0.7);
  z-index: 5;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  opacity: 0.5;
  transition: opacity 0.2s;
  user-select: none;
}

.legend-item.active {
  opacity: 1;
}

.legend-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.legend-text {
  font-size: 12px;
  color: #94a3b8;
}

/* ---- Canvas 画布 ---- */
.starmap-canvas-wrapper {
  flex: 1;
  position: relative;
  overflow: hidden;
}

.starmap-canvas {
  display: block;
  width: 100%;
  height: 100%;
}

/* ---- 加载状态 ---- */
.loading-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: rgba(15, 23, 42, 0.8);
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(148, 163, 184, 0.2);
  border-top-color: #818cf8;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-text {
  margin-top: 16px;
  font-size: 14px;
  color: #94a3b8;
}

/* ---- 空状态 ---- */
.empty-state {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-title {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 8px;
}

.empty-desc {
  font-size: 14px;
  color: #64748b;
}

/* ---- 时间轴 ---- */
.timeline-control {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: rgba(15, 23, 42, 0.9);
  border-top: 1px solid rgba(148, 163, 184, 0.1);
  z-index: 5;
}

.timeline-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: none;
  background: rgba(148, 163, 184, 0.1);
  border-radius: 6px;
  color: #94a3b8;
  cursor: pointer;
  transition: all 0.2s;
}

.timeline-btn:hover:not(:disabled) {
  background: rgba(148, 163, 184, 0.2);
}

.timeline-btn:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.timeline-track {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  position: relative;
}

.timeline-track::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 0;
  right: 0;
  height: 2px;
  background: rgba(148, 163, 184, 0.15);
  transform: translateY(-50%);
}

.timeline-dot {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  cursor: pointer;
  z-index: 1;
}

.timeline-dot::before {
  content: '';
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #475569;
  border: 2px solid #1e293b;
  transition: all 0.2s;
}

.timeline-dot.active::before {
  background: #818cf8;
  border-color: #818cf8;
  box-shadow: 0 0 8px rgba(129, 140, 248, 0.4);
}

.timeline-label {
  position: absolute;
  top: 16px;
  font-size: 10px;
  color: #64748b;
  white-space: nowrap;
}

.timeline-dot.active .timeline-label {
  color: #818cf8;
}

/* ---- 认知摘要面板 ---- */
.summary-panel {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(15, 23, 42, 0.95);
  backdrop-filter: blur(16px);
  border-top: 1px solid rgba(148, 163, 184, 0.15);
  border-radius: 16px 16px 0 0;
  z-index: 20;
  transition: all 0.3s ease;
}

.summary-toggle {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 100%;
  padding: 12px;
  border: none;
  background: none;
  color: #94a3b8;
  font-size: 13px;
  cursor: pointer;
}

.summary-toggle svg {
  transition: transform 0.3s;
}

.summary-content {
  padding: 0 16px 20px;
}

.summary-insight {
  font-size: 15px;
  line-height: 1.6;
  color: #e2e8f0;
  margin-bottom: 16px;
  padding: 12px;
  background: rgba(129, 140, 248, 0.08);
  border-radius: 8px;
  border-left: 3px solid #818cf8;
}

.summary-stats {
  display: flex;
  gap: 16px;
  margin-bottom: 16px;
}

.stat-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px;
  background: rgba(148, 163, 184, 0.06);
  border-radius: 8px;
}

.stat-value {
  font-size: 20px;
  font-weight: 700;
  color: #e2e8f0;
}

.stat-label {
  font-size: 11px;
  color: #64748b;
  margin-top: 4px;
}

.summary-traits,
.summary-growth {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.trait-label {
  font-size: 12px;
  color: #64748b;
}

.trait-tag {
  font-size: 12px;
  padding: 2px 10px;
  background: rgba(245, 158, 11, 0.12);
  color: #f59e0b;
  border-radius: 12px;
}

.growth-tag {
  font-size: 12px;
  padding: 2px 10px;
  background: rgba(16, 185, 129, 0.12);
  color: #10b981;
  border-radius: 12px;
}

/* ---- 节点详情面板 ---- */
.node-detail-panel {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(15, 23, 42, 0.95);
  backdrop-filter: blur(16px);
  border-top: 1px solid rgba(148, 163, 184, 0.15);
  border-radius: 16px 16px 0 0;
  padding: 16px;
  z-index: 30;
}

.detail-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
}

.detail-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
}

.detail-title {
  flex: 1;
  font-size: 16px;
  font-weight: 600;
}

.detail-close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: none;
  background: rgba(148, 163, 184, 0.1);
  border-radius: 6px;
  color: #94a3b8;
  cursor: pointer;
}

.detail-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.detail-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.detail-label {
  width: 60px;
  font-size: 12px;
  color: #64748b;
  flex-shrink: 0;
}

.detail-value {
  font-size: 13px;
  color: #e2e8f0;
}

.detail-bar-wrapper {
  flex: 1;
  height: 6px;
  background: rgba(148, 163, 184, 0.1);
  border-radius: 3px;
  overflow: hidden;
}

.detail-bar {
  height: 100%;
  border-radius: 3px;
  transition: width 0.3s ease;
}

/* ---- 分享弹窗 ---- */
.share-modal-overlay {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.7);
  z-index: 100;
  padding: 20px;
}

/* ---- 动画 ---- */
.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.3s ease;
}

.slide-up-enter-from,
.slide-up-leave-to {
  transform: translateY(100%);
  opacity: 0;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

/* ---- 深色模式已默认 ---- */
@media (prefers-color-scheme: light) {
  .starmap-view {
    background: #f8fafc;
    color: #1e293b;
  }

  .starmap-header {
    background: rgba(248, 250, 252, 0.9);
    border-bottom-color: rgba(148, 163, 184, 0.2);
  }

  .summary-panel,
  .node-detail-panel {
    background: rgba(248, 250, 252, 0.95);
    border-top-color: rgba(148, 163, 184, 0.2);
  }

  .summary-insight {
    color: #1e293b;
  }

  .stat-value {
    color: #1e293b;
  }

  .detail-value {
    color: #1e293b;
  }
}

/* ---- 响应式 ---- */
@media (max-width: 640px) {
  .dimension-legend {
    gap: 8px;
    padding: 6px 12px;
    flex-wrap: wrap;
  }

  .legend-text {
    font-size: 11px;
  }

  .summary-stats {
    gap: 8px;
  }

  .stat-value {
    font-size: 16px;
  }
}
</style>
