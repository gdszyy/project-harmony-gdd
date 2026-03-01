package graph

import (
	"context"
	"fmt"
	"sync"

	"gorm.io/gorm"
)

// TagNode represents a node in the tag knowledge graph.
type TagNode struct {
	TagID     uint64  `json:"tag_id"`
	Name      string  `json:"name"`
	Dimension string  `json:"dimension"`
	Weight    float64 `json:"weight"`
}

// TagEdge represents a directed edge in the tag knowledge graph.
type TagEdge struct {
	SourceID     uint64  `json:"source_id"`
	TargetID     uint64  `json:"target_id"`
	RelationType string  `json:"relation_type"`
	Distance     float64 `json:"distance"`
	Confidence   float64 `json:"confidence"`
}

// AdjacencyGraph provides an in-memory adjacency list representation
// of the tag knowledge graph for efficient traversal operations.
type AdjacencyGraph struct {
	mu       sync.RWMutex
	nodes    map[uint64]*TagNode
	outEdges map[uint64][]*TagEdge // source_id -> edges
	inEdges  map[uint64][]*TagEdge // target_id -> edges
}

// NewAdjacencyGraph creates a new empty adjacency graph.
func NewAdjacencyGraph() *AdjacencyGraph {
	return &AdjacencyGraph{
		nodes:    make(map[uint64]*TagNode),
		outEdges: make(map[uint64][]*TagEdge),
		inEdges:  make(map[uint64][]*TagEdge),
	}
}

// LoadFromDB loads the tag graph from the database.
func (g *AdjacencyGraph) LoadFromDB(ctx context.Context, db *gorm.DB, userID uint64) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	// Clear existing data
	g.nodes = make(map[uint64]*TagNode)
	g.outEdges = make(map[uint64][]*TagEdge)
	g.inEdges = make(map[uint64][]*TagEdge)

	// Load nodes (cognitive_tags)
	var tags []struct {
		ID        uint64  `gorm:"column:id"`
		Name      string  `gorm:"column:name"`
		Dimension string  `gorm:"column:dimension"`
		Weight    float64 `gorm:"column:weight"`
	}
	if err := db.WithContext(ctx).
		Table("cognitive_tags").
		Select("id, name, dimension, weight").
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Find(&tags).Error; err != nil {
		return fmt.Errorf("failed to load tags: %w", err)
	}

	for _, t := range tags {
		g.nodes[t.ID] = &TagNode{
			TagID:     t.ID,
			Name:      t.Name,
			Dimension: t.Dimension,
			Weight:    t.Weight,
		}
	}

	// Load edges (tag_relations)
	var relations []struct {
		SourceTagID  uint64  `gorm:"column:source_tag_id"`
		TargetTagID  uint64  `gorm:"column:target_tag_id"`
		RelationType string  `gorm:"column:relation_type"`
		Distance     float64 `gorm:"column:distance"`
		Confidence   float64 `gorm:"column:confidence"`
	}

	// Build tag ID list for filtering
	tagIDs := make([]uint64, 0, len(g.nodes))
	for id := range g.nodes {
		tagIDs = append(tagIDs, id)
	}

	if len(tagIDs) > 0 {
		if err := db.WithContext(ctx).
			Table("tag_relations").
			Select("source_tag_id, target_tag_id, relation_type, distance, confidence").
			Where("source_tag_id IN ? OR target_tag_id IN ?", tagIDs, tagIDs).
			Find(&relations).Error; err != nil {
			return fmt.Errorf("failed to load relations: %w", err)
		}
	}

	for _, r := range relations {
		edge := &TagEdge{
			SourceID:     r.SourceTagID,
			TargetID:     r.TargetTagID,
			RelationType: r.RelationType,
			Distance:     r.Distance,
			Confidence:   r.Confidence,
		}
		g.outEdges[r.SourceTagID] = append(g.outEdges[r.SourceTagID], edge)
		g.inEdges[r.TargetTagID] = append(g.inEdges[r.TargetTagID], edge)
	}

	return nil
}

// GetNode returns a tag node by ID.
func (g *AdjacencyGraph) GetNode(tagID uint64) (*TagNode, bool) {
	g.mu.RLock()
	defer g.mu.RUnlock()
	node, ok := g.nodes[tagID]
	return node, ok
}

// GetNeighbors returns all directly connected tags with their edge information.
func (g *AdjacencyGraph) GetNeighbors(tagID uint64) []*TagEdge {
	g.mu.RLock()
	defer g.mu.RUnlock()

	var neighbors []*TagEdge
	neighbors = append(neighbors, g.outEdges[tagID]...)
	neighbors = append(neighbors, g.inEdges[tagID]...)
	return neighbors
}

// FindRelatedTags performs a BFS traversal to find tags within a given distance threshold.
// maxDepth limits the traversal depth, maxDistance filters edges by semantic distance.
func (g *AdjacencyGraph) FindRelatedTags(tagID uint64, maxDepth int, maxDistance float64) []*TagNode {
	g.mu.RLock()
	defer g.mu.RUnlock()

	visited := make(map[uint64]bool)
	visited[tagID] = true
	var result []*TagNode

	type queueItem struct {
		id    uint64
		depth int
	}
	queue := []queueItem{{id: tagID, depth: 0}}

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]

		if current.depth >= maxDepth {
			continue
		}

		// Check outgoing edges
		for _, edge := range g.outEdges[current.id] {
			if !visited[edge.TargetID] && edge.Distance <= maxDistance {
				visited[edge.TargetID] = true
				if node, ok := g.nodes[edge.TargetID]; ok {
					result = append(result, node)
					queue = append(queue, queueItem{id: edge.TargetID, depth: current.depth + 1})
				}
			}
		}

		// Check incoming edges (for symmetric relations)
		for _, edge := range g.inEdges[current.id] {
			if !visited[edge.SourceID] && edge.Distance <= maxDistance {
				visited[edge.SourceID] = true
				if node, ok := g.nodes[edge.SourceID]; ok {
					result = append(result, node)
					queue = append(queue, queueItem{id: edge.SourceID, depth: current.depth + 1})
				}
			}
		}
	}

	return result
}

// NodeCount returns the number of nodes in the graph.
func (g *AdjacencyGraph) NodeCount() int {
	g.mu.RLock()
	defer g.mu.RUnlock()
	return len(g.nodes)
}

// EdgeCount returns the number of edges in the graph.
func (g *AdjacencyGraph) EdgeCount() int {
	g.mu.RLock()
	defer g.mu.RUnlock()
	count := 0
	for _, edges := range g.outEdges {
		count += len(edges)
	}
	return count
}
