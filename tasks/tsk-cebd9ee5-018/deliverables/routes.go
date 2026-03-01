package starmap

import (
	"github.com/gin-gonic/gin"
)

// RegisterRoutes 注册认知星图相关路由
//
// 路由列表:
//   GET  /api/v1/users/:id/starmap       - 获取用户认知星图（需认证）
//   POST /api/v1/starmap/share            - 创建星图分享（需认证）
//   GET  /api/v1/starmap/share/:shareId   - 获取分享详情（公开）
func RegisterRoutes(router *gin.RouterGroup, handler *Handler, authMiddleware gin.HandlerFunc) {
	// 需要认证的路由
	authorized := router.Group("")
	if authMiddleware != nil {
		authorized.Use(authMiddleware)
	}
	{
		// 获取用户认知星图
		authorized.GET("/users/:id/starmap", handler.GetStarmap)

		// 创建星图分享
		authorized.POST("/starmap/share", handler.CreateShare)
	}

	// 公开路由（无需认证）
	{
		// 获取分享详情
		router.GET("/starmap/share/:shareId", handler.GetShare)
	}
}
