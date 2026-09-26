#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GitHub Git Data API 稳健推送（针对大仓库 + 弱网优化）。

相比 api_push.py 的改进：
  1. 分批建 tree：按顶层目录分组，先建子树，再拼 root tree，避免单次请求过大导致 502
  2. blob 上传断点续传：把已完成 blob 的 sha 缓存到 .api_push_cache.json，重跑不重复传
  3. 单线程 + 保守节流，规避 secondary rate limit
  4. 所有阶段可重入，任何一步失败重跑都能接着来

用法:
    python api_push_v2.py <owner/repo> <token> [branch]
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.github.com"
CACHE_FILE = ".api_push_cache.json"


def api(method, path, token, data=None, retries=8):
    url = path if path.startswith("http") else f"{API}{path}"
    body = json.dumps(data).encode() if data is not None else None
    last = None
    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("Authorization", f"token {token}")
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("User-Agent", "api-push-v2")
        if body:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="ignore")[:300]
            last = f"HTTP {e.code}: {detail}"
            if e.code in (403, 409, 422, 500, 502, 503, 504):
                wait = 15 * (attempt + 1) if e.code in (403, 502, 503) else 5 * (attempt + 1)
                print(f"   [retry {attempt+1}/{retries}] {method} {url.split('/')[-1]} -> {e.code}, wait {wait}s", flush=True)
                time.sleep(wait)
                continue
            raise RuntimeError(f"{method} {url} -> HTTP {e.code}: {detail}")
        except Exception as e:
            last = str(e)
            wait = 8 * (attempt + 1)
            print(f"   [retry {attempt+1}/{retries}] net err ({last[:60]}), wait {wait}s", flush=True)
            time.sleep(wait)
            continue
    raise RuntimeError(f"{method} {url} -> {last}")


def git(*args):
    return subprocess.check_output(["git"] + list(args), stderr=subprocess.PIPE)


def load_cache():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, encoding="utf-8") as f:
                d = json.load(f)
            print(f">> 载入缓存: {len(d.get('blobs', {}))} 个 blob")
            return d
        except Exception:
            pass
    return {"blobs": {}, "trees": {}}


def save_cache(c):
    tmp = CACHE_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(c, f)
    os.replace(tmp, CACHE_FILE)


def build_nested_tree(owner_repo, token, files, cache):
    """
    files: [(path, blob_sha)]
    按顶层目录分组，逐层建 tree。
    返回 root tree sha。
    """
    # 按顶层目录分组
    groups = {}
    for path, sha in files:
        parts = path.split("/", 1)
        top = parts[0] if len(parts) > 1 else ""
        groups.setdefault(top, []).append((path, sha))

    root_items = []
    for top, items in sorted(groups.items()):
        if top == "":
            # 根目录文件
            for path, sha in items:
                root_items.append({"path": path, "mode": "100644", "type": "blob", "sha": sha})
            continue

        # 需要为这个顶层目录建子树（递归处理其内部）
        sub_sha = build_subtree(owner_repo, token, top, items, cache)
        root_items.append({"path": top, "mode": "040000", "type": "tree", "sha": sub_sha})

    print(f">> 创建 root tree ({len(root_items)} 个顶层条目) ...", flush=True)
    tree = api("POST", f"/repos/{owner_repo}/git/trees", token, {"tree": root_items})
    return tree["sha"]


def build_subtree(owner_repo, token, prefix, items, cache, depth=0):
    """递归构建子树。items 的 path 都以 prefix + '/' 开头。"""
    cache_key = prefix
    if cache_key in cache["trees"]:
        return cache["trees"][cache_key]

    # 去掉 prefix 前缀
    plen = len(prefix) + 1
    entries = {}
    direct = []
    for path, sha in items:
        rel = path[plen:]
        if "/" in rel:
            top = rel.split("/", 1)[0]
            entries.setdefault(top, []).append((path, sha))
        else:
            direct.append({"path": rel, "mode": "100644", "type": "blob", "sha": sha})

    tree_items = list(direct)
    for sub, subitems in sorted(entries.items()):
        sub_sha = build_subtree(owner_repo, token, f"{prefix}/{sub}", subitems, cache, depth + 1)
        tree_items.append({"path": sub, "mode": "040000", "type": "tree", "sha": sub_sha})

    # 大目录分批提交（每批 <= 400 条），用 base_tree 增量拼接
    BATCH = 400
    if len(tree_items) <= BATCH:
        print(f"   tree {prefix} ({len(tree_items)} 项)", flush=True)
        tree = api("POST", f"/repos/{owner_repo}/git/trees", token, {"tree": tree_items})
        cache["trees"][cache_key] = tree["sha"]
        save_cache(cache)
        return tree["sha"]

    # 分批：第一批建成，后续用 base_tree 叠加
    first = tree_items[:BATCH]
    print(f"   tree {prefix} 分批: {len(tree_items)} 项 -> {BATCH}/批", flush=True)
    tree = api("POST", f"/repos/{owner_repo}/git/trees", token, {"tree": first})
    base = tree["sha"]
    for i in range(BATCH, len(tree_items), BATCH):
        chunk = tree_items[i:i + BATCH]
        print(f"      +{len(chunk)} 项 (累计 {i+len(chunk)}/{len(tree_items)})", flush=True)
        tree = api("POST", f"/repos/{owner_repo}/git/trees", token,
                   {"tree": chunk, "base_tree": base})
        base = tree["sha"]
        save_cache(cache)
    cache["trees"][cache_key] = base
    save_cache(cache)
    return base


def main():
    owner_repo = sys.argv[1]
    token = sys.argv[2]
    branch = sys.argv[3] if len(sys.argv) > 3 else "main"

    repo_root = os.path.dirname(os.path.abspath(__file__))
    os.chdir(repo_root)
    print(f">> 目标: {owner_repo}  分支: {branch}")

    raw = git("ls-files", "--stage", "-z").decode("utf-8", errors="surrogateescape")
    entries = []
    for item in raw.split("\0"):
        if not item.strip():
            continue
        meta, path = item.split("\t", 1)
        mode, obj, _ = meta.split()
        entries.append((mode, obj, path))
    print(f">> 文件数: {len(entries)}")

    cache = load_cache()
    blobs = cache["blobs"]

    # 阶段1: 上传 blob（带缓存）
    to_upload = [(m, o, p) for m, o, p in entries if p not in blobs]
    print(f">> 待上传 blob: {len(to_upload)} (已缓存 {len(blobs)})")
    for idx, (mode, obj, path) in enumerate(to_upload, 1):
        try:
            with open(path, "rb") as f:
                content = f.read()
        except OSError:
            continue
        b64 = base64.b64encode(content).decode()
        res = api("POST", f"/repos/{owner_repo}/git/blobs", token,
                  {"content": b64, "encoding": "base64"})
        blobs[path] = res["sha"]
        if idx % 25 == 0 or idx == len(to_upload):
            print(f"   blob {idx}/{len(to_upload)}", flush=True)
            save_cache(cache)
        time.sleep(0.25)

    save_cache(cache)
    print(f">> blob 全部就绪: {len(blobs)} 个")

    # 阶段2: 构建 tree
    files = [(p, blobs[p]) for _, _, p in entries if p in blobs]
    root_sha = build_nested_tree(owner_repo, token, files, cache)
    print(f">> root tree: {root_sha}")

    # 阶段3: commit
    msg = git("log", "-1", "--pretty=%s").decode("utf-8", errors="replace").strip()
    print(f">> 创建 commit: {msg}")
    commit = api("POST", f"/repos/{owner_repo}/git/commits", token, {
        "message": msg,
        "tree": root_sha,
        "author": {"name": "Kiritodxy", "email": "kiritodxy@agent.qq.com"},
        "committer": {"name": "Kiritodxy", "email": "kiritodxy@agent.qq.com"},
    })
    print(f">> commit: {commit['sha']}")

    # 阶段4: 更新引用
    try:
        api("POST", f"/repos/{owner_repo}/git/refs", token,
            {"ref": f"refs/heads/{branch}", "sha": commit["sha"]})
        print(">> 分支已创建")
    except RuntimeError:
        api("PATCH", f"/repos/{owner_repo}/git/refs/heads/{branch}", token,
            {"sha": commit["sha"], "force": True})
        print(">> 分支已更新")

    print()
    print("=" * 60)
    print(" 推送成功 ✅")
    print(f" https://github.com/{owner_repo}/tree/{branch}")
    print("=" * 60)


if __name__ == "__main__":
    main()
