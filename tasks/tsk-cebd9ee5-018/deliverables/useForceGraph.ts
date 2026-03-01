/**
 * useForceGraph - Canvas 2D 力导向图引擎
 *
 * 基于 Verlet 积分的力导向布局算法，支持：
 * - 100+ 节点的高性能 Canvas 渲染
 * - 缩放/平移/拖拽交互
 * - 节点点击事件
 * - 动画帧循环
 *
 * [Sprint2-T19] 认知星图完整可视化核心引擎
 */
import { ref, onMounted, onUnmounted, watch, type Ref } from 'vue'

// ---- 类型定义 ----

export interface ForceNode {
  id: string
  label: string
  displayName?: string
  weight: number           // 0.0 - 1.0
  dimension: CognitiveDimension
  evidenceCount: number
  confidence: number
  firstDetectedAt: number
  lastReinforcedAt: number
  // 力导向布局内部状态
  x: number
  y: number
  vx: number
  vy: number
  fx?: number | null       // 固定位置（拖拽时使用）
  fy?: number | null
  radius: number
  color: string
  isNew?: boolean
}

export interface ForceLink {
  source: string           // node id
  target: string           // node id
  distance: number         // 认知距离 0.0-1.0
  strength: number
}

export type CognitiveDimension =
  | 'understanding_preference'
  | 'focus_domain'
  | 'emotional_tendency'
  | 'thinking_pattern'

// 维度颜色映射
export const DIMENSION_COLORS: Record<CognitiveDimension, string> = {
  understanding_preference: '#F59E0B',  // 琥珀色 - 理解偏好
  focus_domain: '#3B82F6',              // 蓝色 - 关注域
  emotional_tendency: '#EC4899',        // 粉色 - 情绪倾向
  thinking_pattern: '#10B981',          // 绿色 - 思维方式
}

export const DIMENSION_LABELS: Record<CognitiveDimension, string> = {
  understanding_preference: '理解偏好',
  focus_domain: '关注域',
  emotional_tendency: '情绪倾向',
  thinking_pattern: '思维方式',
}

// ---- 力导向引擎参数 ----
const REPULSION_STRENGTH = 800
const LINK_STRENGTH = 0.3
const LINK_DISTANCE_BASE = 120
const CENTER_GRAVITY = 0.02
const DAMPING = 0.92
const MIN_ALPHA = 0.001
const VELOCITY_LIMIT = 10

export interface ForceGraphOptions {
  canvasRef: Ref<HTMLCanvasElement | null>
  nodes: Ref<ForceNode[]>
  links: Ref<ForceLink[]>
  width: Ref<number>
  height: Ref<number>
  onNodeClick?: (node: ForceNode) => void
  onNodeHover?: (node: ForceNode | null) => void
}

export function useForceGraph(options: ForceGraphOptions) {
  const { canvasRef, nodes, links, width, height, onNodeClick, onNodeHover } = options

  // 状态
  const isSimulating = ref(true)
  const alpha = ref(1.0)
  const hoveredNode = ref<ForceNode | null>(null)
  const selectedNode = ref<ForceNode | null>(null)
  const transform = ref({ x: 0, y: 0, k: 1 })

  // 内部状态
  let animationId: number | null = null
  let isDragging = false
  let isPanning = false
  let dragNode: ForceNode | null = null
  let lastMousePos = { x: 0, y: 0 }
  let ctx: CanvasRenderingContext2D | null = null

  // ---- 坐标转换 ----
  function screenToWorld(sx: number, sy: number) {
    return {
      x: (sx - transform.value.x) / transform.value.k,
      y: (sy - transform.value.y) / transform.value.k,
    }
  }

  function worldToScreen(wx: number, wy: number) {
    return {
      x: wx * transform.value.k + transform.value.x,
      y: wy * transform.value.k + transform.value.y,
    }
  }

  // ---- 节点查找 ----
  function findNodeAt(sx: number, sy: number): ForceNode | null {
    const { x, y } = screenToWorld(sx, sy)
    for (let i = nodes.value.length - 1; i >= 0; i--) {
      const node = nodes.value[i]
      const dx = x - node.x
      const dy = y - node.y
      if (dx * dx + dy * dy < (node.radius + 4) * (node.radius + 4)) {
        return node
      }
    }
    return null
  }

  // ---- 力导向模拟 ----
  function simulate() {
    if (alpha.value < MIN_ALPHA) {
      isSimulating.value = false
      return
    }

    const nodeArr = nodes.value
    const linkArr = links.value
    const cx = width.value / 2
    const cy = height.value / 2

    // 1. 斥力（节点间排斥）
    for (let i = 0; i < nodeArr.length; i++) {
      for (let j = i + 1; j < nodeArr.length; j++) {
        const a = nodeArr[i]
        const b = nodeArr[j]
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dist = Math.sqrt(dx * dx + dy * dy) || 1
        const force = (REPULSION_STRENGTH * alpha.value) / (dist * dist)
        const fx = (dx / dist) * force
        const fy = (dy / dist) * force
        if (a.fx == null) { a.vx -= fx; }
        if (a.fy == null) { a.vy -= fy; }
        if (b.fx == null) { b.vx += fx; }
        if (b.fy == null) { b.vy += fy; }
      }
    }

    // 2. 引力（连线弹簧力）
    const nodeMap = new Map(nodeArr.map(n => [n.id, n]))
    for (const link of linkArr) {
      const source = nodeMap.get(link.source)
      const target = nodeMap.get(link.target)
      if (!source || !target) continue

      let dx = target.x - source.x
      let dy = target.y - source.y
      let dist = Math.sqrt(dx * dx + dy * dy) || 1
      const idealDist = LINK_DISTANCE_BASE * (0.5 + link.distance)
      const force = (dist - idealDist) * LINK_STRENGTH * link.strength * alpha.value
      const fx = (dx / dist) * force
      const fy = (dy / dist) * force
      if (source.fx == null) { source.vx += fx; }
      if (source.fy == null) { source.vy += fy; }
      if (target.fx == null) { target.vx -= fx; }
      if (target.fy == null) { target.vy -= fy; }
    }

    // 3. 中心引力
    for (const node of nodeArr) {
      if (node.fx != null || node.fy != null) continue
      node.vx += (cx - node.x) * CENTER_GRAVITY * alpha.value
      node.vy += (cy - node.y) * CENTER_GRAVITY * alpha.value
    }

    // 4. 更新位置
    for (const node of nodeArr) {
      if (node.fx != null) {
        node.x = node.fx
        node.vx = 0
      } else {
        node.vx *= DAMPING
        node.vx = Math.max(-VELOCITY_LIMIT, Math.min(VELOCITY_LIMIT, node.vx))
        node.x += node.vx
      }
      if (node.fy != null) {
        node.y = node.fy
        node.vy = 0
      } else {
        node.vy *= DAMPING
        node.vy = Math.max(-VELOCITY_LIMIT, Math.min(VELOCITY_LIMIT, node.vy))
        node.y += node.vy
      }
    }

    // 衰减 alpha
    alpha.value *= 0.995
  }

  // ---- Canvas 渲染 ----
  function render() {
    if (!ctx || !canvasRef.value) return

    const w = width.value
    const h = height.value
    const dpr = window.devicePixelRatio || 1

    // 清空画布
    ctx.clearRect(0, 0, w * dpr, h * dpr)
    ctx.save()
    ctx.scale(dpr, dpr)

    // 应用变换
    ctx.translate(transform.value.x, transform.value.y)
    ctx.scale(transform.value.k, transform.value.k)

    const nodeMap = new Map(nodes.value.map(n => [n.id, n]))

    // 绘制连线
    for (const link of links.value) {
      const source = nodeMap.get(link.source)
      const target = nodeMap.get(link.target)
      if (!source || !target) continue

      const isHighlighted = hoveredNode.value &&
        (hoveredNode.value.id === link.source || hoveredNode.value.id === link.target)

      ctx.beginPath()
      ctx.moveTo(source.x, source.y)
      ctx.lineTo(target.x, target.y)
      ctx.strokeStyle = isHighlighted
        ? 'rgba(148, 163, 184, 0.6)'
        : 'rgba(148, 163, 184, 0.15)'
      ctx.lineWidth = isHighlighted ? 2 : 1
      ctx.stroke()
    }

    // 绘制节点
    for (const node of nodes.value) {
      const isHovered = hoveredNode.value?.id === node.id
      const isSelected = selectedNode.value?.id === node.id
      const isConnected = hoveredNode.value && links.value.some(
        l => (l.source === hoveredNode.value!.id && l.target === node.id) ||
             (l.target === hoveredNode.value!.id && l.source === node.id)
      )

      // 节点光晕
      if (isHovered || isSelected) {
        ctx.beginPath()
        ctx.arc(node.x, node.y, node.radius + 8, 0, Math.PI * 2)
        ctx.fillStyle = node.color + '20'
        ctx.fill()
      }

      // 脉冲光环（新标签）
      if (node.isNew) {
        ctx.beginPath()
        ctx.arc(node.x, node.y, node.radius + 4, 0, Math.PI * 2)
        ctx.strokeStyle = node.color + '40'
        ctx.lineWidth = 2
        ctx.stroke()
      }

      // 节点主体
      ctx.beginPath()
      ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2)

      // 渐变填充
      const gradient = ctx.createRadialGradient(
        node.x - node.radius * 0.3, node.y - node.radius * 0.3, 0,
        node.x, node.y, node.radius
      )
      gradient.addColorStop(0, node.color + 'FF')
      gradient.addColorStop(1, node.color + 'CC')
      ctx.fillStyle = gradient
      ctx.fill()

      // 节点边框
      if (isHovered || isSelected) {
        ctx.strokeStyle = '#ffffff'
        ctx.lineWidth = 2
        ctx.stroke()
      }

      // 透明度处理
      const dimmed = hoveredNode.value && !isHovered && !isConnected
      if (dimmed) {
        ctx.globalAlpha = 0.3
      }

      // 节点标签
      const fontSize = Math.max(10, Math.min(14, node.radius * 0.9))
      ctx.font = `500 ${fontSize}px 'Inter', 'Noto Sans SC', sans-serif`
      ctx.textAlign = 'center'
      ctx.textBaseline = 'top'
      ctx.fillStyle = dimmed ? 'rgba(100, 116, 139, 0.5)' : 'rgba(51, 65, 85, 0.9)'
      ctx.fillText(
        node.displayName || node.label,
        node.x,
        node.y + node.radius + 6
      )

      ctx.globalAlpha = 1.0
    }

    ctx.restore()
  }

  // ---- 动画循环 ----
  function tick() {
    simulate()
    render()
    animationId = requestAnimationFrame(tick)
  }

  // ---- 事件处理 ----
  function handleMouseDown(e: MouseEvent) {
    const rect = canvasRef.value!.getBoundingClientRect()
    const sx = e.clientX - rect.left
    const sy = e.clientY - rect.top
    const node = findNodeAt(sx, sy)

    if (node) {
      isDragging = true
      dragNode = node
      node.fx = node.x
      node.fy = node.y
      alpha.value = Math.max(alpha.value, 0.3)
      isSimulating.value = true
    } else {
      isPanning = true
    }
    lastMousePos = { x: e.clientX, y: e.clientY }
  }

  function handleMouseMove(e: MouseEvent) {
    const rect = canvasRef.value!.getBoundingClientRect()
    const sx = e.clientX - rect.left
    const sy = e.clientY - rect.top

    if (isDragging && dragNode) {
      const { x, y } = screenToWorld(sx, sy)
      dragNode.fx = x
      dragNode.fy = y
      alpha.value = Math.max(alpha.value, 0.1)
    } else if (isPanning) {
      const dx = e.clientX - lastMousePos.x
      const dy = e.clientY - lastMousePos.y
      transform.value.x += dx
      transform.value.y += dy
      lastMousePos = { x: e.clientX, y: e.clientY }
    } else {
      const node = findNodeAt(sx, sy)
      if (node !== hoveredNode.value) {
        hoveredNode.value = node
        onNodeHover?.(node)
        canvasRef.value!.style.cursor = node ? 'pointer' : 'grab'
      }
    }
  }

  function handleMouseUp(_e: MouseEvent) {
    if (isDragging && dragNode) {
      dragNode.fx = null
      dragNode.fy = null
      dragNode = null
    }
    isDragging = false
    isPanning = false
  }

  function handleClick(e: MouseEvent) {
    const rect = canvasRef.value!.getBoundingClientRect()
    const sx = e.clientX - rect.left
    const sy = e.clientY - rect.top
    const node = findNodeAt(sx, sy)

    if (node) {
      selectedNode.value = node
      onNodeClick?.(node)
    } else {
      selectedNode.value = null
    }
  }

  function handleWheel(e: WheelEvent) {
    e.preventDefault()
    const rect = canvasRef.value!.getBoundingClientRect()
    const sx = e.clientX - rect.left
    const sy = e.clientY - rect.top

    const scaleFactor = e.deltaY > 0 ? 0.92 : 1.08
    const newK = Math.max(0.2, Math.min(5, transform.value.k * scaleFactor))

    // 以鼠标位置为缩放中心
    transform.value.x = sx - (sx - transform.value.x) * (newK / transform.value.k)
    transform.value.y = sy - (sy - transform.value.y) * (newK / transform.value.k)
    transform.value.k = newK
  }

  // ---- Touch 事件支持 ----
  let lastTouchDist = 0

  function handleTouchStart(e: TouchEvent) {
    if (e.touches.length === 1) {
      const touch = e.touches[0]
      const rect = canvasRef.value!.getBoundingClientRect()
      const sx = touch.clientX - rect.left
      const sy = touch.clientY - rect.top
      const node = findNodeAt(sx, sy)

      if (node) {
        isDragging = true
        dragNode = node
        node.fx = node.x
        node.fy = node.y
        alpha.value = Math.max(alpha.value, 0.3)
      } else {
        isPanning = true
      }
      lastMousePos = { x: touch.clientX, y: touch.clientY }
    } else if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX
      const dy = e.touches[0].clientY - e.touches[1].clientY
      lastTouchDist = Math.sqrt(dx * dx + dy * dy)
    }
  }

  function handleTouchMove(e: TouchEvent) {
    e.preventDefault()
    if (e.touches.length === 1) {
      const touch = e.touches[0]
      const rect = canvasRef.value!.getBoundingClientRect()
      const sx = touch.clientX - rect.left
      const sy = touch.clientY - rect.top

      if (isDragging && dragNode) {
        const { x, y } = screenToWorld(sx, sy)
        dragNode.fx = x
        dragNode.fy = y
        alpha.value = Math.max(alpha.value, 0.1)
      } else if (isPanning) {
        const dx = touch.clientX - lastMousePos.x
        const dy = touch.clientY - lastMousePos.y
        transform.value.x += dx
        transform.value.y += dy
      }
      lastMousePos = { x: touch.clientX, y: touch.clientY }
    } else if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX
      const dy = e.touches[0].clientY - e.touches[1].clientY
      const dist = Math.sqrt(dx * dx + dy * dy)
      if (lastTouchDist > 0) {
        const scaleFactor = dist / lastTouchDist
        const midX = (e.touches[0].clientX + e.touches[1].clientX) / 2
        const midY = (e.touches[0].clientY + e.touches[1].clientY) / 2
        const rect = canvasRef.value!.getBoundingClientRect()
        const sx = midX - rect.left
        const sy = midY - rect.top
        const newK = Math.max(0.2, Math.min(5, transform.value.k * scaleFactor))
        transform.value.x = sx - (sx - transform.value.x) * (newK / transform.value.k)
        transform.value.y = sy - (sy - transform.value.y) * (newK / transform.value.k)
        transform.value.k = newK
      }
      lastTouchDist = dist
    }
  }

  function handleTouchEnd(_e: TouchEvent) {
    if (isDragging && dragNode) {
      dragNode.fx = null
      dragNode.fy = null
      dragNode = null
    }
    isDragging = false
    isPanning = false
    lastTouchDist = 0
  }

  // ---- 初始化 ----
  function initCanvas() {
    const canvas = canvasRef.value
    if (!canvas) return

    const dpr = window.devicePixelRatio || 1
    canvas.width = width.value * dpr
    canvas.height = height.value * dpr
    canvas.style.width = `${width.value}px`
    canvas.style.height = `${height.value}px`

    ctx = canvas.getContext('2d')
    if (!ctx) return

    // 初始化节点位置（随机分布在中心区域）
    const cx = width.value / 2
    const cy = height.value / 2
    for (const node of nodes.value) {
      if (!node.x || !node.y) {
        node.x = cx + (Math.random() - 0.5) * width.value * 0.6
        node.y = cy + (Math.random() - 0.5) * height.value * 0.6
      }
      node.vx = 0
      node.vy = 0
      // 计算节点半径（基于权重）
      node.radius = 8 + node.weight * 20 // 8-28px
      node.color = DIMENSION_COLORS[node.dimension] || '#94A3B8'
    }

    // 绑定事件
    canvas.addEventListener('mousedown', handleMouseDown)
    canvas.addEventListener('mousemove', handleMouseMove)
    canvas.addEventListener('mouseup', handleMouseUp)
    canvas.addEventListener('click', handleClick)
    canvas.addEventListener('wheel', handleWheel, { passive: false })
    canvas.addEventListener('touchstart', handleTouchStart, { passive: false })
    canvas.addEventListener('touchmove', handleTouchMove, { passive: false })
    canvas.addEventListener('touchend', handleTouchEnd)

    canvas.style.cursor = 'grab'

    // 启动动画
    alpha.value = 1.0
    isSimulating.value = true
    tick()
  }

  function destroy() {
    if (animationId) {
      cancelAnimationFrame(animationId)
      animationId = null
    }
    const canvas = canvasRef.value
    if (canvas) {
      canvas.removeEventListener('mousedown', handleMouseDown)
      canvas.removeEventListener('mousemove', handleMouseMove)
      canvas.removeEventListener('mouseup', handleMouseUp)
      canvas.removeEventListener('click', handleClick)
      canvas.removeEventListener('wheel', handleWheel)
      canvas.removeEventListener('touchstart', handleTouchStart)
      canvas.removeEventListener('touchmove', handleTouchMove)
      canvas.removeEventListener('touchend', handleTouchEnd)
    }
  }

  // 重置视图
  function resetView() {
    transform.value = { x: 0, y: 0, k: 1 }
  }

  // 重新模拟
  function reheat() {
    alpha.value = 1.0
    isSimulating.value = true
  }

  // 缩放到适合
  function fitView() {
    if (nodes.value.length === 0) return
    let minX = Infinity, maxX = -Infinity
    let minY = Infinity, maxY = -Infinity
    for (const node of nodes.value) {
      minX = Math.min(minX, node.x - node.radius)
      maxX = Math.max(maxX, node.x + node.radius)
      minY = Math.min(minY, node.y - node.radius)
      maxY = Math.max(maxY, node.y + node.radius)
    }
    const padding = 60
    const graphW = maxX - minX + padding * 2
    const graphH = maxY - minY + padding * 2
    const k = Math.min(width.value / graphW, height.value / graphH, 2)
    const cx = (minX + maxX) / 2
    const cy = (minY + maxY) / 2
    transform.value = {
      x: width.value / 2 - cx * k,
      y: height.value / 2 - cy * k,
      k,
    }
  }

  // 监听尺寸变化
  watch([width, height], () => {
    if (canvasRef.value && ctx) {
      const dpr = window.devicePixelRatio || 1
      canvasRef.value.width = width.value * dpr
      canvasRef.value.height = height.value * dpr
      canvasRef.value.style.width = `${width.value}px`
      canvasRef.value.style.height = `${height.value}px`
    }
  })

  onMounted(() => {
    initCanvas()
  })

  onUnmounted(() => {
    destroy()
  })

  return {
    isSimulating,
    alpha,
    hoveredNode,
    selectedNode,
    transform,
    resetView,
    reheat,
    fitView,
    initCanvas,
    destroy,
  }
}
