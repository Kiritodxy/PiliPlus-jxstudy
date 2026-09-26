#!/usr/bin/env bash
# ============================================================
# PiliPlus 江西学习守护版 —— 一键推送到 GitHub
# ------------------------------------------------------------
# 用法（Git Bash）：
#   ./push_to_github.sh <你的PAT>
#
# 前提：
#   1. 已在 GitHub 网页端创建空仓库 Kiritodxy/PiliPlus-jxstudy
#      （不要勾选任何 Initialize 选项，保持完全空白）
#   2. PAT 需要 Contents: Read and write 权限
#      （classic token 勾 repo + workflow；fine-grained 勾
#        Contents=RW、Actions=RW、Metadata=R、Workflows=RW）
# ============================================================
set -euo pipefail

TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "用法: ./push_to_github.sh <你的PAT>" >&2
  exit 1
fi

REPO_OWNER="Kiritodxy"
REPO_NAME="PiliPlus-jxstudy"
BRANCH="main"

cd "$(dirname "$0")"

echo ">> [1/4] 校验 PAT 权限 ..."
SCOPES=$(curl -sS -I -H "Authorization: token $TOKEN" https://api.github.com/user \
  | tr -d '\r' | grep -i '^x-oauth-scopes:' || true)
echo "   Token scopes: ${SCOPES:-<fine-grained token 不返回此头，属正常>}"

echo ">> [2/4] 校验仓库可写 ..."
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME")
if [ "$CODE" != "200" ]; then
  echo "   !! 仓库 $REPO_OWNER/$REPO_NAME 不可访问 (HTTP $CODE)" >&2
  echo "   -> 请先在 https://github.com/new 创建空仓库（不要初始化 README）" >&2
  exit 1
fi
echo "   仓库存在且可访问 ✅"

echo ">> [3/4] 配置带凭据的 remote ..."
git remote remove jxstudy 2>/dev/null || true
git remote add jxstudy "https://${REPO_OWNER}:${TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git"

echo ">> [4/4] 推送 $BRANCH ..."
git push jxstudy "HEAD:${BRANCH}" --force

echo
echo "============================================================"
echo " 推送完成 ✅"
echo " 仓库地址 : https://github.com/$REPO_OWNER/$REPO_NAME"
echo " Actions  : https://github.com/$REPO_OWNER/$REPO_NAME/actions"
echo
echo " 下一步（出 APK）："
echo "   1. 打开 Actions 页面，左侧选 'Build Android APK'"
echo "   2. 点 'Run workflow'，tag 填 v2.1.4-custom.5，运行"
echo "   3. 构建完成后到 Releases 下载 PiliPlus_jxstudy_arm64-v8a.apk"
echo "      （真我 GT Neo5 240W 是 arm64-v8a）"
echo "============================================================"
