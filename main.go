package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"golang.org/x/net/proxy"
)

// ProxyRequest 代理检测请求结构
type ProxyRequest struct {
	ProxyURL string `json:"proxy_url"`
	TestURL  string `json:"test_url,omitempty"` // 可选的测试URL，默认使用httpbin.org
}

// ProxyResponse 代理检测响应结构
type ProxyResponse struct {
	Success    bool    `json:"success"`
	ProxyURL   string  `json:"proxy_url"`
	TestURL    string  `json:"test_url"`
	StatusCode int     `json:"status_code,omitempty"`
	Error      string  `json:"error,omitempty"`
	Duration   float64 `json:"duration_ms"` // 响应时间（毫秒）
}

const (
	DefaultTestURL = "https://www.baidu.com/"
	DefaultTimeout = 2 * time.Second
)

func main() {
	http.HandleFunc("/check", handleProxyCheck)
	http.HandleFunc("/health", handleHealth)
	
	port := ":8080"
	log.Printf("代理检测服务启动在端口 %s", port)
	log.Printf("使用方法:")
	log.Printf("POST /check")
	log.Printf(`请求体: {"proxy_url": "socks5://user:pass@host:port"}`)
	log.Printf("GET /health - 健康检查")
	
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatal("服务启动失败:", err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func handleProxyCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "只支持POST方法", http.StatusMethodNotAllowed)
		return
	}

	var req ProxyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的JSON格式", http.StatusBadRequest)
		return
	}

	if req.ProxyURL == "" {
		http.Error(w, "proxy_url不能为空", http.StatusBadRequest)
		return
	}

	// 设置默认测试URL
	if req.TestURL == "" {
		req.TestURL = DefaultTestURL
	}

	response := checkProxy(req.ProxyURL, req.TestURL)
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func checkProxy(proxyURL, testURL string) ProxyResponse {
	start := time.Now()
	response := ProxyResponse{
		ProxyURL: proxyURL,
		TestURL:  testURL,
	}

	// 解析代理URL
	parsedProxy, err := url.Parse(proxyURL)
	if err != nil {
		response.Error = fmt.Sprintf("代理URL格式错误: %v", err)
		response.Duration = float64(time.Since(start).Nanoseconds()) / 1e6
		return response
	}

	// 创建HTTP客户端
	client, err := createProxyClient(parsedProxy)
	if err != nil {
		response.Error = fmt.Sprintf("创建代理客户端失败: %v", err)
		response.Duration = float64(time.Since(start).Nanoseconds()) / 1e6
		return response
	}

	// 设置超时上下文
	ctx, cancel := context.WithTimeout(context.Background(), DefaultTimeout)
	defer cancel()

	// 创建请求
	req, err := http.NewRequestWithContext(ctx, "GET", testURL, nil)
	if err != nil {
		response.Error = fmt.Sprintf("创建请求失败: %v", err)
		response.Duration = float64(time.Since(start).Nanoseconds()) / 1e6
		return response
	}

	// 发送请求
	resp, err := client.Do(req)
	if err != nil {
		response.Error = fmt.Sprintf("请求失败: %v", err)
		response.Duration = float64(time.Since(start).Nanoseconds()) / 1e6
		return response
	}
	defer resp.Body.Close()

	response.Success = true
	response.StatusCode = resp.StatusCode
	response.Duration = float64(time.Since(start).Nanoseconds()) / 1e6

	return response
}

func createProxyClient(proxyURL *url.URL) (*http.Client, error) {
	scheme := strings.ToLower(proxyURL.Scheme)
	
	switch scheme {
	case "http", "https":
		return createHTTPProxyClient(proxyURL)
	case "socks5":
		return createSOCKS5ProxyClient(proxyURL)
	default:
		return nil, fmt.Errorf("不支持的代理类型: %s", scheme)
	}
}

func createHTTPProxyClient(proxyURL *url.URL) (*http.Client, error) {
	transport := &http.Transport{
		Proxy: http.ProxyURL(proxyURL),
		DialContext: (&net.Dialer{
			Timeout: DefaultTimeout,
		}).DialContext,
	}

	return &http.Client{
		Transport: transport,
		Timeout:   DefaultTimeout,
	}, nil
}

func createSOCKS5ProxyClient(proxyURL *url.URL) (*http.Client, error) {
	// 解析用户名和密码
	var auth *proxy.Auth
	if proxyURL.User != nil {
		password, _ := proxyURL.User.Password()
		auth = &proxy.Auth{
			User:     proxyURL.User.Username(),
			Password: password,
		}
	}

	// 创建SOCKS5拨号器
	dialer, err := proxy.SOCKS5("tcp", proxyURL.Host, auth, &net.Dialer{
		Timeout: DefaultTimeout,
	})
	if err != nil {
		return nil, fmt.Errorf("创建SOCKS5拨号器失败: %v", err)
	}

	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			return dialer.Dial(network, addr)
		},
	}

	return &http.Client{
		Transport: transport,
		Timeout:   DefaultTimeout,
	}, nil
}

