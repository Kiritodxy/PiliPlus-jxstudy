#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用 GitHub Git Data API 推送本地 git 仓库到远端。
绕开不可用的 git over HTTPS 通道，仅依赖 api.github.com。

用法:
    python api_push.py <owner/repo> <token> [branch]
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

API = "https://api.github.com"


def api(method, path, token, data=None, retries=6):
    url = path if path.startswith("http") else f"{API}{path}"
    body = json.dumps(data).encode() if data is not None else None
    last = None
    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("Authorization", f"token {token}")
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("User-Agent", "api-push")
        if body:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="ignore")[:400]
            # 403 secondary rate limit / 409 / 422 均属可重试
            if e.code in (403, 409, 422) and "secondary rate limit" in detail or e.code in (409, 422):
                wait = 5 * (attempt + 1)
                if "secondary rate limit" in detail or e.code == 403:
                    wait = 20 * (attempt + 1)
                time.sleep(wait)
                last = f"HTTP {e.code}: {detail}"
                continue
            raise RuntimeError(f"{method} {url} -> HTTP {e.code}: {detail}")
        except Exception as e:  # 网络抖动
            last = str(e)
            if attempt < retries - 1:
                time.sleep(1.5 * (attempt + 1))
                continue
            raise RuntimeError(f"{method} {url} -> {last}")
    raise RuntimeError(last)


def git(*args):
    return subprocess.check_output(["git"] + list(args), stderr=subprocess.PIPE)


def main():
    owner_repo = sys.argv[1]
    token = sys.argv[2]
    branch = sys.argv[3] if len(sys.argv) > 3 else "main"
    
    repo_root = os.path.dirname(os.path.abspath(__file__))
    os.chdir(repo_root)

    print(f">> 目标仓库: {owner_repo}  分支: {branch}")

    # 1. 收集文件清单 (mode, sha, path)
    raw = git("ls-files", "--stage", "-z").decode("utf-8", errors="surrogateescape")
    entries = []
    for item in raw.split("\0"):
        if not item.strip():
            continue
        meta, path = item.split("\t", 1)
        mode, obj, stage = meta.split()
        entries.append((mode, obj, path))
    print(f">> 文件数: {len(entries)}")

    # 2. 创建 root tree 前，先并发上传所有 blob
    def make_blob(entry):
        mode, obj, path = entry
        try:
            with open(path, "rb") as f:
                content = f.read()
        except OSError:
            # 可能是子模块 (mode 160000)，跳过
            return None
        b64 = base64.b64encode(content).decode()
        res = api("POST", f"/repos/{owner_repo}/git/blobs", token,
                  {"content": b64, "encoding": "base64"})
        return (path, res["sha"], mode)

    done = 0
    results = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        for r in pool.map(make_blob, entries):
            done += 1
            if r:
                results.append(r)
            if done % 50 == 0:
                print(f"   已上传 {done}/{len(entries)}", flush=True)
            time.sleep(0.12)

    print(f">> blob 上传完成: {len(results)} 个")

    # 3. 构造 tree（扁平结构，GitHub 会自动处理嵌套）
    tree_items = []
    for path, sha, mode in results:
        m = "100755" if mode == "100755" else "100644"
        tree_items.append({"path": path, "mode": m, "type": "blob", "sha": sha})

    print(">> 创建 tree ...")
    tree = api("POST", f"/repos/{owner_repo}/git/trees", token, {"tree": tree_items})
    print(f"   tree sha: {tree['sha']}")

    # 4. 创建 commit
    msg = git("log", "-1", "--pretty=%s").decode("utf-8", errors="replace").strip()
    author_name = "Kiritodxy"
    author_email = "kiritodxy@agent.qq.com"
    print(f">> 创建 commit: {msg}")
    commit = api("POST", f"/repos/{owner_repo}/git/commits", token, {
        "message": msg,
        "tree": tree["sha"],
        "author": {"name": author_name, "email": author_email},
        "committer": {"name": author_name, "email": author_email},
    })
    print(f"   commit sha: {commit['sha']}")

    # 5. 创建/更新 branch 引用
    print(f">> 更新分支 {branch} ...")
    try:
        api("POST", f"/repos/{owner_repo}/git/refs", token,
            {"ref": f"refs/heads/{branch}", "sha": commit["sha"]})
        print("   已创建分支")
    except RuntimeError as e:
        if "422" in str(e) or "409" in str(e):
            api("PATCH", f"/repos/{owner_repo}/git/refs/heads/{branch}", token,
                {"sha": commit["sha"], "force": True})
            print("   已更新分支")
        else:
            raise

    print()
    print("=" * 60)
    print(f" 推送成功 ✅")
    print(f" https://github.com/{owner_repo}/tree/{branch}")
    print("=" * 60)


if __name__ == "__main__":
    main()
