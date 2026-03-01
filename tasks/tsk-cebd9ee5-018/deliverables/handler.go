package starmap

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler 提供认知星图的 HTTP 接口
type Handler struct {
	service *Service
}

// NewHandler 创建 Handler 实例
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// GetStarmap 获取用户认知星图
// GET /api/v1/users/:id/starmap
func (h *Handler) GetStarmap(c *gin.Context) {
	userIDStr := c.Param("id")

	// 支持 "me" 作为当前用户的别名
	var userID uint64
	if userIDStr == "me" {
		// 从 JWT 上下文获取当前用户 ID
		uid, exists := c.Get("userID")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code":    10001,
				"message": "未登录",
			})
			return
		}
		userID = uid.(uint64)
	} else {
		var err error
		userID, err = strconv.ParseUint(userIDStr, 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"code":    20002,
				"message": "无效的用户 ID",
			})
			return
		}
	}

	// TODO: 从用户服务获取用户名和头像
	// 当前使用占位值，实际应从 users 表查询
	userName := "用户" + strconv.FormatUint(userID, 10)
	avatarURL := ""

	resp, err := h.service.GetStarmap(userID, userName, avatarURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    50001,
			"message": "获取星图数据失败",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":      0,
		"message":   "success",
		"data":      resp,
		"timestamp": time.Now().UnixMilli(),
	})
}

// CreateShare 创建星图分享
// POST /api/v1/starmap/share
func (h *Handler) CreateShare(c *gin.Context) {
	// 获取当前用户 ID
	uid, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    10001,
			"message": "未登录",
		})
		return
	}
	userID := uid.(uint64)

	// 解析请求
	var req ShareRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"code":    20001,
			"message": "请求参数错误",
			"details": err.Error(),
		})
		return
	}

	// 获取当前星图数据
	resp, err := h.service.GetStarmap(userID, "", "")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    50001,
			"message": "获取星图数据失败",
		})
		return
	}

	// 序列化快照数据
	snapshotJSON, err := json.Marshal(resp.CurrentSnapshot)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    50002,
			"message": "序列化数据失败",
		})
		return
	}

	// 生成分享 ID
	shareID := uuid.New().String()
	expiresAt := uint64(time.Now().Add(7 * 24 * time.Hour).UnixMilli()) // 7 天有效期

	// 保存分享记录
	share := &StarmapShare{
		UserID:       userID,
		ShareID:      shareID,
		Theme:        req.Theme,
		SnapshotData: string(snapshotJSON),
		ExpiresAt:    expiresAt,
	}

	if err := h.service.repo.CreateShare(share); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    50003,
			"message": "创建分享失败",
		})
		return
	}

	// 构建分享 URL
	baseURL := c.Request.Header.Get("X-Base-URL")
	if baseURL == "" {
		baseURL = fmt.Sprintf("%s://%s", c.Request.URL.Scheme, c.Request.Host)
		if baseURL == "://" {
			baseURL = "https://edgereader.app"
		}
	}
	shareURL := fmt.Sprintf("%s/share/%s", baseURL, shareID)
	qrCodeURL := fmt.Sprintf("%s/api/v1/starmap/share/%s/qr", baseURL, shareID)

	c.JSON(http.StatusOK, gin.H{
		"code":    0,
		"message": "success",
		"data": ShareResponse{
			ShareID:   shareID,
			ShareURL:  shareURL,
			QRCodeURL: qrCodeURL,
			ExpiresAt: expiresAt,
		},
		"timestamp": time.Now().UnixMilli(),
	})
}

// GetShare 获取分享详情（公开接口，无需认证）
// GET /api/v1/starmap/share/:shareId
func (h *Handler) GetShare(c *gin.Context) {
	shareID := c.Param("shareId")

	share, err := h.service.repo.GetShareByID(shareID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"code":    30001,
			"message": "分享不存在或已过期",
		})
		return
	}

	// 检查是否过期
	if share.ExpiresAt < NowMillis() {
		c.JSON(http.StatusGone, gin.H{
			"code":    30002,
			"message": "分享已过期",
		})
		return
	}

	// 增加浏览次数
	_ = h.service.repo.IncrementShareViewCount(shareID)

	// 解析快照数据
	var snapshot StarmapSnapshot
	if err := json.Unmarshal([]byte(share.SnapshotData), &snapshot); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    50004,
			"message": "解析分享数据失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    0,
		"message": "success",
		"data": gin.H{
			"shareId":   share.ShareID,
			"theme":     share.Theme,
			"snapshot":  snapshot,
			"viewCount": share.ViewCount + 1,
			"createdAt": share.CreatedAt,
			"expiresAt": share.ExpiresAt,
		},
		"timestamp": time.Now().UnixMilli(),
	})
}
