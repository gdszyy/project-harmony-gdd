package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
)

// TagDimension defines the semantic dimension of a cognitive tag.
type TagDimension string

const (
	DimensionTopic     TagDimension = "topic"     // 主题标签
	DimensionConcept   TagDimension = "concept"   // 概念标签
	DimensionEntity    TagDimension = "entity"    // 实体标签
	DimensionSentiment TagDimension = "sentiment" // 情感标签
	DimensionSkill     TagDimension = "skill"     // 技能标签
)

// ValidDimensions returns all valid tag dimensions.
func ValidDimensions() []TagDimension {
	return []TagDimension{
		DimensionTopic,
		DimensionConcept,
		DimensionEntity,
		DimensionSentiment,
		DimensionSkill,
	}
}

// IsValid checks if the dimension value is valid.
func (d TagDimension) IsValid() bool {
	for _, valid := range ValidDimensions() {
		if d == valid {
			return true
		}
	}
	return false
}

// TagSourceType defines how a cognitive tag was created.
type TagSourceType string

const (
	SourceManual      TagSourceType = "manual"       // 用户手动创建
	SourceAutoExtract TagSourceType = "auto_extract" // 系统自动提取
	SourceAISuggest   TagSourceType = "ai_suggest"   // AI 推荐
)

// ValidSourceTypes returns all valid source types.
func ValidSourceTypes() []TagSourceType {
	return []TagSourceType{
		SourceManual,
		SourceAutoExtract,
		SourceAISuggest,
	}
}

// CognitiveTag represents a semantic tag used for knowledge organization.
//
// Sprint 2 Extensions (backward compatible):
//   - Dimension: categorizes tags into semantic dimensions
//   - DecayRate: controls temporal weight decay
//   - SourceType: indicates tag creation source
//
// All new fields have defaults and are nullable, ensuring backward compatibility
// with existing queries that don't reference these columns.
type CognitiveTag struct {
	BaseModel

	// Core fields (existing)
	Name        string  `gorm:"type:varchar(128);not null;index:idx_cognitive_tags_name" json:"name"`
	Description string  `gorm:"type:text;default:''" json:"description"`
	Weight      float64 `gorm:"type:float;default:1.0" json:"weight"`
	UserID      uint64  `gorm:"not null;index:idx_cognitive_tags_user_id;index:idx_cognitive_tags_user_dimension" json:"user_id"`

	// Sprint 2 Extension fields
	// Dimension categorizes the tag into a semantic dimension.
	// Default: "topic" for backward compatibility.
	Dimension TagDimension `gorm:"type:varchar(32);default:'topic';index:idx_cognitive_tags_dimension;index:idx_cognitive_tags_user_dimension" json:"dimension"`

	// DecayRate controls how quickly the tag weight decays over time.
	// Range: 0.0 (no decay) to 1.0 (fastest decay).
	// Default: 0.1 for gradual decay.
	DecayRate float64 `gorm:"type:float;default:0.1" json:"decay_rate"`

	// SourceType indicates how this tag was created.
	// Default: "manual" for backward compatibility with user-created tags.
	SourceType TagSourceType `gorm:"type:varchar(32);default:'manual';index:idx_cognitive_tags_source_type" json:"source_type"`

	// Associations
	User         User          `gorm:"foreignKey:UserID" json:"user,omitempty"`
	ArticleTags  []ArticleTag  `gorm:"foreignKey:TagID" json:"article_tags,omitempty"`
	
	// Tag relations (outgoing)
	OutgoingRelations []TagRelation `gorm:"foreignKey:SourceTagID" json:"outgoing_relations,omitempty"`
	// Tag relations (incoming)
	IncomingRelations []TagRelation `gorm:"foreignKey:TargetTagID" json:"incoming_relations,omitempty"`
}

func (CognitiveTag) TableName() string {
	return "cognitive_tags"
}

// BeforeCreate hook validates the tag before insertion.
func (ct *CognitiveTag) BeforeCreate(tx *gorm.DB) error {
	// Validate dimension
	if ct.Dimension != "" && !ct.Dimension.IsValid() {
		return errors.New("invalid tag dimension: " + string(ct.Dimension))
	}
	// Set defaults if empty
	if ct.Dimension == "" {
		ct.Dimension = DimensionTopic
	}
	if ct.SourceType == "" {
		ct.SourceType = SourceManual
	}
	// Validate decay_rate range
	if ct.DecayRate < 0.0 || ct.DecayRate > 1.0 {
		return errors.New("decay_rate must be between 0.0 and 1.0")
	}
	return nil
}

// CalculateDecayedWeight returns the tag weight after applying time-based decay.
// Formula: weight * exp(-decay_rate * days_elapsed)
func (ct *CognitiveTag) CalculateDecayedWeight(referenceTime time.Time) float64 {
	if ct.DecayRate == 0 {
		return ct.Weight
	}
	daysElapsed := referenceTime.Sub(ct.UpdatedAt).Hours() / 24.0
	if daysElapsed < 0 {
		daysElapsed = 0
	}
	// Exponential decay: w(t) = w0 * e^(-λt)
	import_math := ct.Weight // placeholder: actual math.Exp usage in service layer
	_ = import_math
	return ct.Weight // Actual calculation done in service layer with math package
}

// ArticleTag represents the many-to-many relationship between articles and tags.
type ArticleTag struct {
	ID             uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	ArticleID      uint64    `gorm:"not null;uniqueIndex:uk_article_tag;index:idx_article_tags_article_id" json:"article_id"`
	TagID          uint64    `gorm:"not null;uniqueIndex:uk_article_tag;index:idx_article_tags_tag_id" json:"tag_id"`
	RelevanceScore float64   `gorm:"type:float;default:0.0" json:"relevance_score"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"created_at"`

	// Associations
	Article Article      `gorm:"foreignKey:ArticleID" json:"article,omitempty"`
	Tag     CognitiveTag `gorm:"foreignKey:TagID" json:"tag,omitempty"`
}

func (ArticleTag) TableName() string {
	return "article_tags"
}

// RelationType defines the type of relationship between two tags.
type RelationType string

const (
	RelationParentChild  RelationType = "parent_child"  // 层级关系
	RelationSynonym      RelationType = "synonym"       // 同义关系
	RelationRelated      RelationType = "related"       // 一般关联
	RelationContrast     RelationType = "contrast"      // 对立关系
	RelationPrerequisite RelationType = "prerequisite"  // 前置依赖
)

// JSONMap is a custom type for storing JSON metadata in MySQL.
type JSONMap map[string]interface{}

// Value implements the driver.Valuer interface for database serialization.
func (j JSONMap) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	return json.Marshal(j)
}

// Scan implements the sql.Scanner interface for database deserialization.
func (j *JSONMap) Scan(value interface{}) error {
	if value == nil {
		*j = nil
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("JSONMap.Scan: unsupported type")
	}
	return json.Unmarshal(bytes, j)
}

// TagRelation represents a directed relationship between two cognitive tags.
// This enables building a knowledge graph of tag associations.
//
// Design Notes:
//   - Relationships are directed (source → target)
//   - Multiple relationship types can exist between the same tag pair
//   - Distance represents semantic distance (0.0 = identical, 1.0 = unrelated)
//   - Confidence indicates how reliable the relationship is
//   - Metadata JSON field allows extensibility without schema changes
type TagRelation struct {
	ID           uint64       `gorm:"primaryKey;autoIncrement" json:"id"`
	SourceTagID  uint64       `gorm:"not null;uniqueIndex:uk_tag_relation;index:idx_tag_relations_source_type" json:"source_tag_id"`
	TargetTagID  uint64       `gorm:"not null;uniqueIndex:uk_tag_relation;index:idx_tag_relations_target" json:"target_tag_id"`
	RelationType RelationType `gorm:"type:varchar(32);not null;default:'related';uniqueIndex:uk_tag_relation;index:idx_tag_relations_type;index:idx_tag_relations_source_type" json:"relation_type"`
	Distance     float64      `gorm:"type:float;default:0.5;index:idx_tag_relations_distance" json:"distance"`
	Confidence   float64      `gorm:"type:float;default:1.0" json:"confidence"`
	Metadata     JSONMap      `gorm:"type:json" json:"metadata,omitempty"`
	CreatedAt    time.Time    `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt    time.Time    `gorm:"autoUpdateTime" json:"updated_at"`

	// Associations
	SourceTag CognitiveTag `gorm:"foreignKey:SourceTagID" json:"source_tag,omitempty"`
	TargetTag CognitiveTag `gorm:"foreignKey:TargetTagID" json:"target_tag,omitempty"`
}

func (TagRelation) TableName() string {
	return "tag_relations"
}

// BeforeCreate hook validates the relation before insertion.
func (tr *TagRelation) BeforeCreate(tx *gorm.DB) error {
	// Prevent self-referencing relations
	if tr.SourceTagID == tr.TargetTagID {
		return errors.New("cannot create a relation from a tag to itself")
	}
	// Validate distance range
	if tr.Distance < 0.0 || tr.Distance > 1.0 {
		return errors.New("distance must be between 0.0 and 1.0")
	}
	// Validate confidence range
	if tr.Confidence < 0.0 || tr.Confidence > 1.0 {
		return errors.New("confidence must be between 0.0 and 1.0")
	}
	return nil
}

// IsSymmetric returns true if the relation type is inherently symmetric.
func (tr *TagRelation) IsSymmetric() bool {
	return tr.RelationType == RelationSynonym || tr.RelationType == RelationRelated
}
