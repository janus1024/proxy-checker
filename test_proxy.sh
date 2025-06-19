#!/bin/bash

# 代理检测服务测试脚本

echo "=== 代理检测服务测试 ==="
echo

# 服务健康检查
echo "1. 健康检查:"
curl -s http://localhost:8080/health | jq '.'
echo

# 测试SOCKS5代理
echo "2. 测试SOCKS5代理:"
curl -s -X POST http://localhost:8080/check \
  -H "Content-Type: application/json" \
  -d '{
    "proxy_url": "socks5://5B3AA05B:F9636FCFC9B4@60.188.79.124:20099"
  }' | jq '.'
echo

# 测试HTTP代理
echo "3. 测试HTTP代理:"
curl -s -X POST http://localhost:8080/check \
  -H "Content-Type: application/json" \
  -d '{
    "proxy_url": "http://5B3AA05B:F9636FCFC9B4@60.188.79.124:20099"
  }' | jq '.'
echo

# 测试自定义URL
echo "4. 测试自定义测试URL:"
curl -s -X POST http://localhost:8080/check \
  -H "Content-Type: application/json" \
  -d '{
    "proxy_url": "http://5B3AA05B:F9636FCFC9B4@60.188.79.124:20099",
    "test_url": "https://httpbin.org/ip"
  }' | jq '.'
echo

# 测试无效代理
echo "5. 测试无效代理URL:"
curl -s -X POST http://localhost:8080/check \
  -H "Content-Type: application/json" \
  -d '{
    "proxy_url": "invalid-proxy-url"
  }' | jq '.'
echo

echo "=== 测试完成 ==="

