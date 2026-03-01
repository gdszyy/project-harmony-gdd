package errors

import (
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

// ──────────────────────────────────────────────────────────────────────────────
// BizError 基础功能测试
// ──────────────────────────────────────────────────────────────────────────────

func TestBizError_Error(t *testing.T) {
	err := New(1001, http.StatusUnauthorized, "未认证")
	if err.Error() != "[1001] 未认证" {
		t.Errorf("expected '[1001] 未认证', got '%s'", err.Error())
	}
}

func TestBizError_ErrorWithCause(t *testing.T) {
	cause := fmt.Errorf("token expired")
	err := ErrTokenExpired.WithCause(cause)
	expected := "[1002] 登录已过期，请重新登录: token expired"
	if err.Error() != expected {
		t.Errorf("expected '%s', got '%s'", expected, err.Error())
	}
}

func TestBizError_Unwrap(t *testing.T) {
	cause := fmt.Errorf("db connection refused")
	err := ErrDBFailed.WithCause(cause)
	if !errors.Is(err, cause) {
		t.Error("Unwrap should allow errors.Is to find the cause")
	}
}

func TestBizError_Is(t *testing.T) {
	// 同一错误码应匹配
	err := ErrArticleNotFound.WithDetails("article_id=123")
	if !errors.Is(err, ErrArticleNotFound) {
		t.Error("errors.Is should match same error code")
	}

	// 不同错误码不应匹配
	if errors.Is(err, ErrUserNotFound) {
		t.Error("errors.Is should not match different error code")
	}
}

func TestBizError_As(t *testing.T) {
	cause := fmt.Errorf("underlying error")
	err := ErrDBFailed.WithCause(cause)
	wrapped := fmt.Errorf("service layer: %w", err)

	var bizErr *BizError
	if !errors.As(wrapped, &bizErr) {
		t.Fatal("errors.As should find BizError in chain")
	}
	if bizErr.Code != 4002 {
		t.Errorf("expected code 4002, got %d", bizErr.Code)
	}
}

func TestBizError_WithDetails(t *testing.T) {
	err := ErrInvalidParam.WithDetails("field 'email' is required")
	if err.Details != "field 'email' is required" {
		t.Errorf("expected details, got '%s'", err.Details)
	}
	// 原始错误不应被修改
	if ErrInvalidParam.Details != "" {
		t.Error("original error should not be modified")
	}
}

func TestBizError_Wrap(t *testing.T) {
	cause := fmt.Errorf("connection timeout")
	err := ErrAITimeout.Wrap(cause, "调用 OpenAI 超时")
	if err.Details != "调用 OpenAI 超时" {
		t.Errorf("expected details, got '%s'", err.Details)
	}
	if !errors.Is(err, cause) {
		t.Error("wrapped error should contain cause")
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// 辅助函数测试
// ──────────────────────────────────────────────────────────────────────────────

func TestIsBizError(t *testing.T) {
	if !IsBizError(ErrInternal) {
		t.Error("ErrInternal should be BizError")
	}
	if IsBizError(fmt.Errorf("plain error")) {
		t.Error("plain error should not be BizError")
	}
}

func TestGetCode(t *testing.T) {
	if GetCode(ErrArticleNotFound) != 2001 {
		t.Errorf("expected 2001, got %d", GetCode(ErrArticleNotFound))
	}
	if GetCode(fmt.Errorf("plain error")) != ErrInternal.Code {
		t.Errorf("expected %d for plain error", ErrInternal.Code)
	}
}

func TestGetHTTPStatus(t *testing.T) {
	if GetHTTPStatus(ErrRateLimited) != http.StatusTooManyRequests {
		t.Errorf("expected 429, got %d", GetHTTPStatus(ErrRateLimited))
	}
	if GetHTTPStatus(fmt.Errorf("plain")) != http.StatusInternalServerError {
		t.Errorf("expected 500 for plain error")
	}
}

func TestWrapErr(t *testing.T) {
	// nil 返回 nil
	if WrapErr(nil) != nil {
		t.Error("WrapErr(nil) should return nil")
	}

	// BizError 直接返回
	result := WrapErr(ErrArticleNotFound)
	if result.Code != 2001 {
		t.Errorf("expected 2001, got %d", result.Code)
	}

	// 普通 error 包装为 ErrInternal
	result = WrapErr(fmt.Errorf("something broke"))
	if result.Code != ErrInternal.Code {
		t.Errorf("expected %d, got %d", ErrInternal.Code, result.Code)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// 错误码完整性测试
// ──────────────────────────────────────────────────────────────────────────────

func TestErrorCodeRanges(t *testing.T) {
	authErrors := []*BizError{
		ErrUnauthorized, ErrTokenExpired, ErrTokenInvalid,
		ErrPermissionDenied, ErrAccountLocked, ErrPasswordWeak,
		ErrRateLimited, ErrRefreshTokenInvalid, ErrUserNotFound, ErrLoginFailed,
	}
	for _, e := range authErrors {
		if e.Code < 1000 || e.Code >= 2000 {
			t.Errorf("auth error code %d out of range [1000, 2000)", e.Code)
		}
	}

	articleErrors := []*BizError{
		ErrArticleNotFound, ErrArticleAlreadyExists, ErrArticleContentEmpty,
		ErrAnnotationNotFound, ErrProgressNotFound, ErrInvalidParam,
		ErrMissingParam, ErrPayloadTooLarge, ErrMaliciousInput, ErrContentUploadFailed,
	}
	for _, e := range articleErrors {
		if e.Code < 2000 || e.Code >= 3000 {
			t.Errorf("article error code %d out of range [2000, 3000)", e.Code)
		}
	}

	aiErrors := []*BizError{
		ErrAITimeout, ErrAIRateLimited, ErrAIProviderUnavailable,
		ErrAIResponseInvalid, ErrAICostLimitExceeded, ErrAIModelNotSupported,
	}
	for _, e := range aiErrors {
		if e.Code < 3000 || e.Code >= 4000 {
			t.Errorf("AI error code %d out of range [3000, 4000)", e.Code)
		}
	}

	sysErrors := []*BizError{
		ErrInternal, ErrDBFailed, ErrCacheFailed, ErrCacheMiss,
		ErrS3Failed, ErrConfigInvalid, ErrServiceUnavailable,
	}
	for _, e := range sysErrors {
		if e.Code < 4000 || e.Code >= 5000 {
			t.Errorf("system error code %d out of range [4000, 5000)", e.Code)
		}
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// API 响应测试
// ──────────────────────────────────────────────────────────────────────────────

func TestRespondError(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)

	RespondError(c, ErrArticleNotFound)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", w.Code)
	}
	body := w.Body.String()
	if body == "" {
		t.Error("response body should not be empty")
	}
}

func TestRespondError_PlainError(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)

	RespondError(c, fmt.Errorf("unexpected error"))

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected status 500, got %d", w.Code)
	}
}

func TestRespondSuccess(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)

	RespondSuccess(c, map[string]string{"hello": "world"})

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// 错误链深度测试
// ──────────────────────────────────────────────────────────────────────────────

func TestErrorChain(t *testing.T) {
	// 模拟多层错误包装
	dbErr := fmt.Errorf("connection refused")
	repoErr := ErrDBFailed.Wrap(dbErr, "query articles failed")
	serviceErr := fmt.Errorf("content service: %w", repoErr)
	handlerErr := fmt.Errorf("handler: %w", serviceErr)

	// 应该能通过错误链找到 BizError
	var bizErr *BizError
	if !errors.As(handlerErr, &bizErr) {
		t.Fatal("should find BizError in deep chain")
	}
	if bizErr.Code != 4002 {
		t.Errorf("expected code 4002, got %d", bizErr.Code)
	}

	// 应该能通过错误链找到原始 cause
	if !errors.Is(handlerErr, dbErr) {
		t.Error("should find original cause in chain")
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// ErrorHandlerMiddleware 测试
// ──────────────────────────────────────────────────────────────────────────────

func TestErrorHandlerMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(ErrorHandlerMiddleware(false))
	router.GET("/test", func(c *gin.Context) {
		_ = c.Error(ErrArticleNotFound)
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/test", nil)
	router.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestErrorHandlerMiddleware_NoError(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(ErrorHandlerMiddleware(false))
	router.GET("/ok", func(c *gin.Context) {
		RespondSuccess(c, "ok")
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/ok", nil)
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}
