// Package errors 提供 EdgeReader 统一业务错误码体系。
//
// 设计原则:
//   - 所有业务错误通过 BizError 类型表达，携带错误码、消息和可选详情
//   - 使用 fmt.Errorf("%w", err) 风格包装，保留完整错误链
//   - 支持 Go 1.13+ errors.Is / errors.As 进行错误判断
//   - 统一 API 错误响应格式 {code, message, details, timestamp}
//
// 错误码分段:
//
//	1xxx — 认证与授权
//	2xxx — 文章与内容
//	3xxx — AI 服务
//	4xxx — 系统与基础设施
package errors

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// ──────────────────────────────────────────────────────────────────────────────
// BizError 业务错误类型
// ──────────────────────────────────────────────────────────────────────────────

// BizError 表示一个携带业务错误码的错误。
// 它同时实现了 error 接口，并可通过 errors.Is / errors.As 进行匹配。
type BizError struct {
	Code       int    // 业务错误码
	Message    string // 面向用户的错误消息
	Details    string // 可选的详细说明（调试用，不暴露给生产环境前端）
	HTTPStatus int    // 对应的 HTTP 状态码
	cause      error  // 被包装的底层错误
}

// Error 实现 error 接口。
func (e *BizError) Error() string {
	if e.cause != nil {
		return fmt.Sprintf("[%d] %s: %v", e.Code, e.Message, e.cause)
	}
	return fmt.Sprintf("[%d] %s", e.Code, e.Message)
}

// Unwrap 支持 errors.Is / errors.As 沿错误链向下查找。
func (e *BizError) Unwrap() error {
	return e.cause
}

// Is 允许按错误码进行 errors.Is 匹配。
// 只要两个 BizError 的 Code 相同即视为同一类错误。
func (e *BizError) Is(target error) bool {
	var t *BizError
	if errors.As(target, &t) {
		return e.Code == t.Code
	}
	return false
}

// WithDetails 返回一个携带详情的新 BizError 副本。
func (e *BizError) WithDetails(details string) *BizError {
	cp := *e
	cp.Details = details
	return &cp
}

// WithCause 返回一个包装了底层 cause 的新 BizError 副本。
func (e *BizError) WithCause(cause error) *BizError {
	cp := *e
	cp.cause = cause
	return &cp
}

// Wrap 同时设置 details 和 cause，等价于 WithDetails(...).WithCause(...)。
func (e *BizError) Wrap(cause error, details string) *BizError {
	cp := *e
	cp.cause = cause
	cp.Details = details
	return &cp
}

// ──────────────────────────────────────────────────────────────────────────────
// 构造函数
// ──────────────────────────────────────────────────────────────────────────────

// New 创建一个新的 BizError。
func New(code int, httpStatus int, message string) *BizError {
	return &BizError{
		Code:       code,
		HTTPStatus: httpStatus,
		Message:    message,
	}
}

// Newf 创建一个带格式化消息的 BizError。
func Newf(code int, httpStatus int, format string, args ...interface{}) *BizError {
	return &BizError{
		Code:       code,
		HTTPStatus: httpStatus,
		Message:    fmt.Sprintf(format, args...),
	}
}

// WrapErr 将任意 error 包装为 BizError。
// 如果 err 本身已经是 BizError，则直接返回；否则包装为 ErrInternal。
func WrapErr(err error) *BizError {
	if err == nil {
		return nil
	}
	var bizErr *BizError
	if errors.As(err, &bizErr) {
		return bizErr
	}
	return ErrInternal.WithCause(err)
}

// ──────────────────────────────────────────────────────────────────────────────
// 1xxx — 认证与授权错误
// ──────────────────────────────────────────────────────────────────────────────

var (
	// ErrUnauthorized 未认证（缺少或无效的 Token）
	ErrUnauthorized = New(1001, http.StatusUnauthorized, "未认证，请先登录")
	// ErrTokenExpired Token 已过期
	ErrTokenExpired = New(1002, http.StatusUnauthorized, "登录已过期，请重新登录")
	// ErrTokenInvalid Token 格式无效
	ErrTokenInvalid = New(1003, http.StatusUnauthorized, "无效的认证令牌")
	// ErrPermissionDenied 权限不足
	ErrPermissionDenied = New(1004, http.StatusForbidden, "权限不足")
	// ErrAccountLocked 账户被锁定
	ErrAccountLocked = New(1005, http.StatusForbidden, "账户已被锁定，请稍后再试")
	// ErrPasswordWeak 密码不符合安全策略
	ErrPasswordWeak = New(1006, http.StatusBadRequest, "密码不符合安全策略要求")
	// ErrRateLimited 请求频率超限
	ErrRateLimited = New(1007, http.StatusTooManyRequests, "请求过于频繁，请稍后再试")
	// ErrRefreshTokenInvalid Refresh Token 无效
	ErrRefreshTokenInvalid = New(1008, http.StatusUnauthorized, "刷新令牌无效或已过期")
	// ErrUserNotFound 用户不存在
	ErrUserNotFound = New(1009, http.StatusNotFound, "用户不存在")
	// ErrLoginFailed 登录失败（用户名或密码错误）
	ErrLoginFailed = New(1010, http.StatusUnauthorized, "用户名或密码错误")
)

// ──────────────────────────────────────────────────────────────────────────────
// 2xxx — 文章与内容错误
// ──────────────────────────────────────────────────────────────────────────────

var (
	// ErrArticleNotFound 文章不存在
	ErrArticleNotFound = New(2001, http.StatusNotFound, "文章不存在")
	// ErrArticleAlreadyExists 文章已存在（重复导入）
	ErrArticleAlreadyExists = New(2002, http.StatusConflict, "文章已存在")
	// ErrArticleContentEmpty 文章内容为空
	ErrArticleContentEmpty = New(2003, http.StatusBadRequest, "文章内容不能为空")
	// ErrAnnotationNotFound 标注不存在
	ErrAnnotationNotFound = New(2004, http.StatusNotFound, "标注不存在")
	// ErrProgressNotFound 阅读进度不存在
	ErrProgressNotFound = New(2005, http.StatusNotFound, "阅读进度不存在")
	// ErrInvalidParam 请求参数无效
	ErrInvalidParam = New(2006, http.StatusBadRequest, "请求参数无效")
	// ErrMissingParam 缺少必要参数
	ErrMissingParam = New(2007, http.StatusBadRequest, "缺少必要参数")
	// ErrPayloadTooLarge 请求体过大
	ErrPayloadTooLarge = New(2008, http.StatusRequestEntityTooLarge, "请求体过大")
	// ErrMaliciousInput 检测到恶意输入
	ErrMaliciousInput = New(2009, http.StatusBadRequest, "检测到非法输入")
	// ErrContentUploadFailed 内容上传失败
	ErrContentUploadFailed = New(2010, http.StatusInternalServerError, "内容上传失败")
)

// ──────────────────────────────────────────────────────────────────────────────
// 3xxx — AI 服务错误
// ──────────────────────────────────────────────────────────────────────────────

var (
	// ErrAITimeout AI 服务超时
	ErrAITimeout = New(3001, http.StatusGatewayTimeout, "AI 服务响应超时")
	// ErrAIRateLimited AI 服务频率限制
	ErrAIRateLimited = New(3002, http.StatusTooManyRequests, "AI 服务请求过于频繁")
	// ErrAIProviderUnavailable AI 服务提供商不可用
	ErrAIProviderUnavailable = New(3003, http.StatusServiceUnavailable, "AI 服务暂时不可用")
	// ErrAIResponseInvalid AI 返回结果无效
	ErrAIResponseInvalid = New(3004, http.StatusInternalServerError, "AI 服务返回结果异常")
	// ErrAICostLimitExceeded AI 成本超限
	ErrAICostLimitExceeded = New(3005, http.StatusServiceUnavailable, "AI 服务今日额度已用完")
	// ErrAIModelNotSupported 不支持的 AI 模型
	ErrAIModelNotSupported = New(3006, http.StatusBadRequest, "不支持的 AI 模型")
)

// ──────────────────────────────────────────────────────────────────────────────
// 4xxx — 系统与基础设施错误
// ──────────────────────────────────────────────────────────────────────────────

var (
	// ErrInternal 通用内部错误
	ErrInternal = New(4001, http.StatusInternalServerError, "服务器内部错误")
	// ErrDBFailed 数据库操作失败
	ErrDBFailed = New(4002, http.StatusInternalServerError, "数据库操作失败")
	// ErrCacheFailed 缓存操作失败
	ErrCacheFailed = New(4003, http.StatusInternalServerError, "缓存服务异常")
	// ErrCacheMiss 缓存未命中（内部使用，不直接返回给客户端）
	ErrCacheMiss = New(4004, http.StatusInternalServerError, "缓存未命中")
	// ErrS3Failed 对象存储操作失败
	ErrS3Failed = New(4005, http.StatusInternalServerError, "文件存储服务异常")
	// ErrConfigInvalid 配置无效
	ErrConfigInvalid = New(4006, http.StatusInternalServerError, "服务配置异常")
	// ErrServiceUnavailable 服务不可用
	ErrServiceUnavailable = New(4007, http.StatusServiceUnavailable, "服务暂时不可用，请稍后再试")
)

// ──────────────────────────────────────────────────────────────────────────────
// 判断辅助函数
// ──────────────────────────────────────────────────────────────────────────────

// IsBizError 判断 err 是否为 BizError 类型。
func IsBizError(err error) bool {
	var bizErr *BizError
	return errors.As(err, &bizErr)
}

// GetCode 从 error 中提取业务错误码；非 BizError 返回 4001（内部错误）。
func GetCode(err error) int {
	var bizErr *BizError
	if errors.As(err, &bizErr) {
		return bizErr.Code
	}
	return ErrInternal.Code
}

// GetHTTPStatus 从 error 中提取 HTTP 状态码；非 BizError 返回 500。
func GetHTTPStatus(err error) int {
	var bizErr *BizError
	if errors.As(err, &bizErr) {
		return bizErr.HTTPStatus
	}
	return http.StatusInternalServerError
}

// ──────────────────────────────────────────────────────────────────────────────
// 统一 API 错误响应
// ──────────────────────────────────────────────────────────────────────────────

// ErrorResponse 统一 API 错误响应结构体。
type ErrorResponse struct {
	Code      int    `json:"code"`              // 业务错误码
	Message   string `json:"message"`           // 面向用户的错误消息
	Details   string `json:"details,omitempty"` // 可选详情（仅 debug 模式）
	Timestamp int64  `json:"timestamp"`         // 毫秒级时间戳
}

// SuccessResponse 统一 API 成功响应结构体。
type SuccessResponse struct {
	Code      int         `json:"code"`              // 0 表示成功
	Message   string      `json:"message"`           // "success"
	Data      interface{} `json:"data,omitempty"`    // 响应数据
	Timestamp int64       `json:"timestamp"`         // 毫秒级时间戳
}

// RespondError 向 gin.Context 写入统一格式的错误响应。
// 如果 err 是 BizError，使用其 Code / HTTPStatus / Message；
// 否则包装为 ErrInternal。
// showDetails 控制是否在响应中暴露 Details 字段（生产环境应为 false）。
func RespondError(c *gin.Context, err error, showDetails ...bool) {
	bizErr := WrapErr(err)
	resp := ErrorResponse{
		Code:      bizErr.Code,
		Message:   bizErr.Message,
		Timestamp: time.Now().UnixMilli(),
	}
	if len(showDetails) > 0 && showDetails[0] && bizErr.Details != "" {
		resp.Details = bizErr.Details
	}
	c.AbortWithStatusJSON(bizErr.HTTPStatus, resp)
}

// RespondSuccess 向 gin.Context 写入统一格式的成功响应。
func RespondSuccess(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, SuccessResponse{
		Code:      0,
		Message:   "success",
		Data:      data,
		Timestamp: time.Now().UnixMilli(),
	})
}

// ──────────────────────────────────────────────────────────────────────────────
// 错误处理中间件
// ──────────────────────────────────────────────────────────────────────────────

// ErrorHandlerMiddleware 是一个 Gin 中间件，用于统一捕获和转换 handler 中
// 通过 c.Error() 注册的错误为标准 API 错误响应。
//
// 用法：在 handler 中使用 c.Error(err) 注册错误，中间件会自动处理。
// 如果 handler 已经自行写入了响应（c.Writer.Written()），中间件不会覆盖。
func ErrorHandlerMiddleware(debugMode bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		// 如果没有错误或已经写入响应，跳过
		if len(c.Errors) == 0 || c.Writer.Written() {
			return
		}

		// 取最后一个错误
		lastErr := c.Errors.Last().Err
		RespondError(c, lastErr, debugMode)
	}
}
