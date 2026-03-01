// Package api 提供 HTTP 路由注册和 API 入口
package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/gdszyy/edge-reader/server/api/handler"
	"github.com/gdszyy/edge-reader/server/api/middleware"
	ws "github.com/gdszyy/edge-reader/server/api/websocket"
	"github.com/gdszyy/edge-reader/server/internal/auth"
	"gorm.io/gorm"
)

// SetupRouter 配置并返回 Gin 路由引擎
// [SEC-P0-1] 新增 authHandler 参数用于注册 refresh 和 logout 端点
// rdb 参数用于 Rate Limiting 中间件的 Redis 连接（可为 nil，将降级为无限流模式）
// db 参数用于 Annotation Handler 的数据库连接
func SetupRouter(jwtSecret string, hub *ws.Hub, rdb *redis.Client, db *gorm.DB, authHandler *auth.AuthHandler) *gin.Engine {
	r := gin.New()

	// ========== 全局中间件（按执行顺序注册） ==========
	// 1. Panic 恢复（最先注册，确保所有 panic 都能被捕获）
	r.Use(middleware.Recovery())
	// 2. 请求 ID（用于日志追踪）
	r.Use(middleware.RequestIDMiddleware())
	// 3. 请求日志
	r.Use(middleware.Logger())
	// 4. 安全响应头
	r.Use(middleware.SecurityHeaders())
	// 5. CORS 跨域控制（收紧为仅允许特定域名）
	r.Use(middleware.CORS())
	// 6. 输入验证与 XSS 过滤
	r.Use(middleware.InputValidation())
	// 7. 全局频率限制（100次/分钟）
	r.Use(middleware.RateLimit(rdb, middleware.RateLimitGlobal))

	// ========== 健康检查接口（不受认证限制） ==========
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "edge-reader-api",
		})
	})

	// 初始化 Handler
	annotationHandler := handler.NewAnnotationHandler(db)
	feedbackHandler := handler.NewFeedbackHandler(db)

	// ========== API v1 路由组 ==========
	v1 := r.Group("/api/v1")
	{
		// ---------- 认证相关路由（无需 JWT，但有更严格的频率限制） ----------
		authGroup := v1.Group("/auth")
		authGroup.Use(middleware.RateLimit(rdb, middleware.RateLimitAuth)) // 5次/分钟
		{
			authGroup.GET("/login", placeholderHandler("auth.login"))
			authGroup.GET("/callback", placeholderHandler("auth.callback"))

			// [SEC-P0-1] Token 刷新端点（Refresh Token 从 HttpOnly Cookie 自动获取）
			authGroup.POST("/refresh", authHandler.HandleRefresh)

			// 登出端点（支持已认证和未认证状态）
			authGroup.POST("/logout", authHandler.HandleLogout)

			// 以下需要认证
			authRequired := authGroup.Group("")
			authRequired.Use(middleware.JWTAuth(jwtSecret))
			{
				authRequired.GET("/me", placeholderHandler("auth.me"))
				authRequired.PUT("/me", placeholderHandler("auth.updateMe"))
			}
		}

		// ---------- 文章相关路由 ----------
		articles := v1.Group("/articles")
		articles.Use(middleware.JWTAuth(jwtSecret))
		{
			articles.GET("", placeholderHandler("articles.list"))
			articles.GET("/:id", placeholderHandler("articles.get"))
			articles.GET("/:id/content", placeholderHandler("articles.getContent"))
		}

		// ---------- 阅读相关路由 ----------
		reading := v1.Group("/reading")
		reading.Use(middleware.JWTAuth(jwtSecret))
		{
			reading.GET("/progress", placeholderHandler("reading.listProgress"))
			reading.GET("/progress/:articleId", placeholderHandler("reading.getProgress"))
			reading.PUT("/progress/:articleId", placeholderHandler("reading.updateProgress"))
		}

		// ---------- 标注相关路由（已实现完整 CRUD） ----------
		annotations := v1.Group("/annotations")
		annotations.Use(middleware.JWTAuth(jwtSecret))
		{
			annotations.GET("", annotationHandler.List)
			annotations.POST("", annotationHandler.Create)
			annotations.PUT("/:id", annotationHandler.Update)
			annotations.DELETE("/:id", annotationHandler.Delete)
		}

		// ---------- AI 对话相关路由（更严格的频率限制） ----------
		conversations := v1.Group("/conversations")
		conversations.Use(middleware.JWTAuth(jwtSecret))
		conversations.Use(middleware.RateLimit(rdb, middleware.RateLimitConversations)) // 20次/分钟
		{
			conversations.GET("", placeholderHandler("conversations.list"))
			conversations.POST("", placeholderHandler("conversations.create"))
			conversations.GET("/:id/messages", placeholderHandler("conversations.listMessages"))
			conversations.POST("/:id/messages", placeholderHandler("conversations.sendMessage"))
		}

		// ---------- 推荐相关路由 ----------
		recommend := v1.Group("/recommend")
		recommend.Use(middleware.JWTAuth(jwtSecret))
		{
			recommend.GET("/feed", placeholderHandler("recommend.feed"))
		}

		// ---------- 推荐反馈路由（负反馈机制） ----------
		recommendations := v1.Group("/recommendations")
		recommendations.Use(middleware.JWTAuth(jwtSecret))
		{
			recommendations.POST("/:id/feedback", feedbackHandler.SubmitFeedback)
			recommendations.GET("/feedbacks", feedbackHandler.GetUserFeedbacks)
		}

		// ---------- 认知标签相关路由 ----------
		cognitive := v1.Group("/cognitive")
		cognitive.Use(middleware.JWTAuth(jwtSecret))
		{
			cognitive.GET("/tags", placeholderHandler("cognitive.tags"))
		}

		// ---------- 管理员路由 ----------
		admin := v1.Group("/admin")
		admin.Use(middleware.JWTAuth(jwtSecret))
		admin.Use(middleware.AdminOnly())
		{
			admin.POST("/articles", placeholderHandler("admin.createArticle"))
			admin.PUT("/articles/:id", placeholderHandler("admin.updateArticle"))
			admin.DELETE("/articles/:id", placeholderHandler("admin.deleteArticle"))
		}
	}

	// ========== WebSocket 路由 ==========
	// [BE-P1-3] 不再从 URL Query 获取 Token
	// 连接建立后，客户端通过第一条消息进行握手认证
	wsGroup := r.Group("")
	wsGroup.Use(middleware.RateLimit(rdb, middleware.RateLimitWebSocket)) // 10次/分钟
	wsGroup.GET("/ws", func(c *gin.Context) {
		hub.ServeWS(c)
	})

	return r
}

// placeholderHandler 返回一个占位 Handler，用于尚未实现的接口
// 在后续开发中，将被具体的业务 Handler 替换
func placeholderHandler(name string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"message": "Not implemented yet",
			"handler": name,
		})
	}
}
