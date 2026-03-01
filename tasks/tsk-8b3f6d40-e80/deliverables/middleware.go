// Package logger 提供日志脱敏中间件。
//
// SanitizeLoggerMiddleware 是一个 Gin 中间件，在日志输出前自动对
// URL 查询参数、Request Body 和 Response Body 中的敏感信息进行脱敏。
//
// 使用方式：
//
//	sanitizer := logger.NewSanitizer(logger.DefaultSanitizerConfig())
//	r.Use(logger.SanitizeLoggerMiddleware(sanitizer))
package logger

import (
	"bytes"
	"io"
	"log"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// sanitizedResponseWriter 包装 gin.ResponseWriter，用于捕获响应体
type sanitizedResponseWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

// Write 拦截写入操作，同时写入缓冲区
func (w *sanitizedResponseWriter) Write(b []byte) (int, error) {
	w.body.Write(b)
	return w.ResponseWriter.Write(b)
}

// SanitizeLoggerMiddleware 返回一个 Gin 中间件，自动对请求和响应日志进行脱敏。
//
// 该中间件会：
//  1. 对 URL 查询参数中的敏感字段进行掩码
//  2. 对 Request Body（JSON）中的敏感字段进行掩码
//  3. 对 Response Body 中的 JWT Token 进行截断
//  4. 所有脱敏后的信息写入日志
//
// 注意：该中间件应在 Recovery 中间件之后、业务路由之前注册。
func SanitizeLoggerMiddleware(sanitizer *Sanitizer) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		// 1. 脱敏 URL
		path := c.Request.URL.Path
		rawQuery := c.Request.URL.RawQuery
		sanitizedPath := path
		if rawQuery != "" {
			fullURL := path + "?" + rawQuery
			sanitizedPath = sanitizer.SanitizeURL(fullURL)
		}

		// 2. 读取并脱敏 Request Body（仅对 JSON 类型）
		var sanitizedBody string
		contentType := c.GetHeader("Content-Type")
		if isJSONContentType(contentType) && c.Request.Body != nil {
			bodyBytes, err := io.ReadAll(c.Request.Body)
			if err == nil && len(bodyBytes) > 0 {
				// 恢复 Body 供后续 Handler 使用
				c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

				// 脱敏 Body
				bodyStr := string(bodyBytes)
				if len(bodyStr) > 4096 {
					// 超长 Body 只记录前 4096 字节
					sanitizedBody = sanitizer.SanitizeJSON(bodyStr[:4096]) + "...[TRUNCATED]"
				} else {
					sanitizedBody = sanitizer.SanitizeJSON(bodyStr)
				}
			}
		}

		// 3. 包装 ResponseWriter 以捕获响应体
		srw := &sanitizedResponseWriter{
			ResponseWriter: c.Writer,
			body:           bytes.NewBufferString(""),
		}
		c.Writer = srw

		// 执行后续 Handler
		c.Next()

		// 4. 计算耗时
		latency := time.Since(start)
		statusCode := c.Writer.Status()
		clientIP := c.ClientIP()
		method := c.Request.Method

		// 5. 脱敏响应体中的敏感信息（仅记录，不修改实际响应）
		respBody := srw.body.String()
		sanitizedResp := ""
		if len(respBody) > 0 && isJSONContentType(c.Writer.Header().Get("Content-Type")) {
			if len(respBody) > 2048 {
				sanitizedResp = sanitizer.Sanitize(respBody[:2048]) + "...[TRUNCATED]"
			} else {
				sanitizedResp = sanitizer.Sanitize(respBody)
			}
		}

		// 6. 输出脱敏后的日志
		logEntry := buildLogEntry(method, sanitizedPath, statusCode, latency, clientIP, sanitizedBody, sanitizedResp)
		log.Print(logEntry)
	}
}

// buildLogEntry 构建格式化的日志条目
func buildLogEntry(method, path string, status int, latency time.Duration, clientIP, reqBody, respBody string) string {
	var sb strings.Builder
	sb.WriteString("[GIN-SANITIZED] ")
	sb.WriteString(time.Now().Format("2006/01/02 - 15:04:05"))
	sb.WriteString(" | ")

	// 状态码
	sb.WriteString(statusString(status))
	sb.WriteString(" | ")

	// 耗时
	sb.WriteString(latency.String())
	sb.WriteString(" | ")

	// 客户端 IP
	sb.WriteString(clientIP)
	sb.WriteString(" | ")

	// 方法和路径
	sb.WriteString(method)
	sb.WriteString(" ")
	sb.WriteString(path)

	// Request Body（如果有）
	if reqBody != "" {
		sb.WriteString(" | body: ")
		sb.WriteString(reqBody)
	}

	// Response Body 摘要（如果有）
	if respBody != "" {
		sb.WriteString(" | resp: ")
		sb.WriteString(respBody)
	}

	sb.WriteString("\n")
	return sb.String()
}

// statusString 返回状态码的字符串表示
func statusString(code int) string {
	switch {
	case code >= 200 && code < 300:
		return "\033[97;42m " + intToStr(code) + " \033[0m"
	case code >= 300 && code < 400:
		return "\033[90;47m " + intToStr(code) + " \033[0m"
	case code >= 400 && code < 500:
		return "\033[90;43m " + intToStr(code) + " \033[0m"
	default:
		return "\033[97;41m " + intToStr(code) + " \033[0m"
	}
}

// intToStr 简单的整数转字符串
func intToStr(n int) string {
	if n == 0 {
		return "0"
	}
	digits := ""
	neg := false
	if n < 0 {
		neg = true
		n = -n
	}
	for n > 0 {
		digits = string(rune('0'+n%10)) + digits
		n /= 10
	}
	if neg {
		digits = "-" + digits
	}
	return digits
}

// isJSONContentType 判断 Content-Type 是否为 JSON
func isJSONContentType(contentType string) bool {
	return strings.Contains(strings.ToLower(contentType), "application/json")
}
