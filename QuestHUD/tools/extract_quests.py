#!/usr/bin/env python3
# pyright: reportUnknownMemberType=false, reportUnknownVariableType=false, reportUnknownArgumentType=false, reportUnknownLambdaType=false
"""
QuestHUD Blizzard Quest Data Extractor
======================================
Fetches World of Warcraft quest data from the Blizzard Game Data API and writes
normalized outputs for local addon workflows.

Outputs:
- JSON file with extracted quest records
- Lua file with a quest lookup table keyed by quest ID
- Optional in-place update of QuestHUD_RouteData.lua quest IDs by quest name

Usage examples:
    python extract_quests.py --region us --namespace static-us --details
    python extract_quests.py --region eu --namespace static-eu --details \
        --update-route-data ../QuestHUD_RouteData.lua

Credentials:
    Set environment variables:
      BLIZZARD_CLIENT_ID
      BLIZZARD_CLIENT_SECRET

    Or pass command-line args:
      --client-id
      --client-secret

Requirements:
- Python 3.8+
- Standard library only
"""

from __future__ import annotations

import argparse
import base64
import concurrent.futures
import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Iterable, Optional, Tuple


TOKEN_PATH = "/oauth/token"
GAME_DATA_BASE = "/data/wow"
DEFAULT_OAUTH_HOST = "oauth.battle.net"
CN_OAUTH_HOST = "oauth.battlenet.com.cn"
CN_API_HOST = "gateway.battlenet.com.cn"


def now_utc_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def make_auth_header(client_id: str, client_secret: str) -> str:
    raw = f"{client_id}:{client_secret}".encode("utf-8")
    return "Basic " + base64.b64encode(raw).decode("ascii")


def request_json(
    url: str,
    headers: dict[str, str],
    method: str = "GET",
    data: Optional[bytes] = None,
    retries: int = 4,
    retry_delay: float = 0.75,
) -> dict[str, Any]:
    last_err: Optional[Exception] = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(url=url, method=method, headers=headers, data=data)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode("utf-8")
                return json.loads(body)
        except urllib.error.HTTPError as err:
            # Retry on throttling and transient server failures.
            if err.code in (429, 500, 502, 503, 504) and attempt < retries:
                retry_after = err.headers.get("Retry-After") if err.headers else None
                if retry_after and retry_after.isdigit():
                    time.sleep(max(float(retry_after), retry_delay))
                else:
                    time.sleep(retry_delay * attempt)
                last_err = err
                continue
            raise
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as err:
            if attempt < retries:
                time.sleep(retry_delay * attempt)
                last_err = err
                continue
            raise

    if last_err:
        raise last_err
    raise RuntimeError("Unhandled request error state")


def get_access_token(region: str, client_id: str, client_secret: str) -> str:
    oauth_host = CN_OAUTH_HOST if region == "cn" else DEFAULT_OAUTH_HOST
    token_url = f"https://{oauth_host}{TOKEN_PATH}"
    headers = {
        "Authorization": make_auth_header(client_id, client_secret),
        "Content-Type": "application/x-www-form-urlencoded",
    }
    data = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode("ascii")
    payload = request_json(token_url, headers=headers, method="POST", data=data)
    token = payload.get("access_token")
    if not token:
        raise RuntimeError("Could not retrieve OAuth access token")
    return token


def build_game_data_url(
    region: str,
    path: str,
    namespace: str,
    locale: str,
    extra: Optional[dict[str, str]] = None,
) -> str:
    q = {
        "namespace": namespace,
        "locale": locale,
    }
    if extra:
        q.update(extra)
    api_host = CN_API_HOST if region == "cn" else f"{region}.api.blizzard.com"
    return f"https://{api_host}{path}?{urllib.parse.urlencode(q)}"


def extract_name(value: Optional[dict[str, Any]]) -> Optional[str]:
    if isinstance(value, dict):
        name = value.get("name")
        if isinstance(name, str):
            return name
    return None


def normalize_quest_record(
    detail: dict[str, Any], fallback_id: int, fallback_name: str
) -> dict[str, Any]:
    rewards = detail.get("rewards", {}) if isinstance(detail.get("rewards"), dict) else {}
    xp = rewards.get("experience")

    return {
        "id": detail.get("id", fallback_id),
        "name": detail.get("title") or detail.get("name") or fallback_name,
        "category": extract_name(detail.get("category")),
        "area": extract_name(detail.get("area")),
        "type": extract_name(detail.get("type")),
        "minimum_level": detail.get("minimum_level"),
        "level": detail.get("level"),
        "is_daily": bool(detail.get("is_daily")),
        "is_weekly": bool(detail.get("is_weekly")),
        "is_repeatable": bool(detail.get("is_repeatable")),
        "suggested_party_members": detail.get("suggested_party_members"),
        "experience": xp if isinstance(xp, int) else None,
    }


def slugify_name(name: str) -> str:
    lowered = name.lower().strip()
    lowered = re.sub(r"[^a-z0-9]+", "_", lowered)
    return lowered.strip("_")


def lua_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "")
    )


def write_json(path: str, payload: dict[str, Any]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")


def write_lua(path: str, metadata: dict[str, Any], quests: list[dict[str, Any]]) -> None:
    lines: list[str] = []
    generated_at = str(metadata.get("generated_at", ""))
    region = str(metadata.get("region", ""))
    namespace = str(metadata.get("namespace", ""))
    locale = str(metadata.get("locale", ""))
    quest_count = int(metadata.get("quest_count", 0))

    lines.append("-- QuestHUD_QuestAPIData.lua")
    lines.append("-- Auto-generated by tools/extract_quests.py")
    lines.append(f"-- Generated: {generated_at}")
    lines.append(f"-- Region: {region}  Namespace: {namespace}  Locale: {locale}")
    lines.append(f"-- Quest count: {quest_count}")
    lines.append("")
    lines.append("QuestHUD_BlizzardQuestData = {")
    lines.append(f"    generated_at = \"{lua_escape(generated_at)}\",")
    lines.append(f"    region = \"{lua_escape(region)}\",")
    lines.append(f"    namespace = \"{lua_escape(namespace)}\",")
    lines.append(f"    locale = \"{lua_escape(locale)}\",")
    lines.append("    quests = {")

    for q in sorted(quests, key=lambda x: x["id"]):
        qid = q["id"]
        name = lua_escape(q.get("name") or "")
        category = q.get("category")
        area = q.get("area")
        qtype = q.get("type")
        level = q.get("level")
        min_level = q.get("minimum_level")
        exp = q.get("experience")
        daily = "true" if q.get("is_daily") else "false"
        weekly = "true" if q.get("is_weekly") else "false"
        repeatable = "true" if q.get("is_repeatable") else "false"

        lines.append(f"        [{qid}] = {{")
        lines.append(f"            name = \"{name}\",")
        if category:
            lines.append(f"            category = \"{lua_escape(category)}\",")
        if area:
            lines.append(f"            area = \"{lua_escape(area)}\",")
        if qtype:
            lines.append(f"            type = \"{lua_escape(qtype)}\",")
        if isinstance(level, int):
            lines.append(f"            level = {level},")
        if isinstance(min_level, int):
            lines.append(f"            minimum_level = {min_level},")
        if isinstance(exp, int):
            lines.append(f"            experience = {exp},")
        lines.append(f"            is_daily = {daily},")
        lines.append(f"            is_weekly = {weekly},")
        lines.append(f"            is_repeatable = {repeatable},")
        lines.append("        },")

    lines.append("    },")
    lines.append("}")
    lines.append("")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def read_quest_index(
    region: str,
    token: str,
    namespace: str,
    locale: str,
) -> list[Tuple[int, str]]:
    url = build_game_data_url(region, f"{GAME_DATA_BASE}/quest/index", namespace, locale)
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    try:
        payload = request_json(url, headers=headers)
    except urllib.error.HTTPError as err:
        if err.code == 404:
            print("Quest index endpoint not available for this region/namespace.")
            return []
        raise
    refs = payload.get("quests") or []

    result: list[Tuple[int, str]] = []
    for ref in refs:
        if not isinstance(ref, dict):
            continue
        qid = ref.get("id")
        name = ref.get("name") or ""
        if isinstance(qid, int) and qid > 0:
            result.append((qid, name))

    if result:
        return result

    # Fallback: if the index endpoint is empty/unavailable for the namespace,
    # enumerate quest IDs through the search API pagination.
    print("Quest index returned no entries, falling back to /search/quest ...")

    seen: dict[int, str] = {}
    page = 1
    page_count = 1

    while page <= page_count:
        search_url = build_game_data_url(
            region,
            f"{GAME_DATA_BASE}/search/quest",
            namespace,
            locale,
            extra={"orderby": "id", "_page": str(page)},
        )
        try:
            search_payload = request_json(search_url, headers=headers)
        except urllib.error.HTTPError as err:
            if err.code == 404:
                print("Quest search endpoint not available; stopping fallback.")
                break
            raise

        results = search_payload.get("results") or []
        if isinstance(results, list):
            for entry in results:
                if not isinstance(entry, dict):
                    continue
                data = entry.get("data")
                if not isinstance(data, dict):
                    continue
                qid = data.get("id")
                title = data.get("title") or data.get("name") or ""
                if isinstance(qid, int) and qid > 0:
                    seen[qid] = title if isinstance(title, str) else ""

        pc = search_payload.get("pageCount")
        if isinstance(pc, int) and pc > 0:
            page_count = pc

        if page % 25 == 0:
            print(f"  search pages fetched: {page}/{page_count}")
        page += 1

    result = sorted(seen.items(), key=lambda x: x[0])
    return result


def fetch_quest_details(
    region: str,
    token: str,
    namespace: str,
    locale: str,
    quest_refs: Iterable[Tuple[int, str]],
    workers: int,
) -> list[dict[str, Any]]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }

    refs = list(quest_refs)

    def fetch_one(ref: Tuple[int, str]) -> dict[str, Any]:
        qid, fallback_name = ref
        url = build_game_data_url(region, f"{GAME_DATA_BASE}/quest/{qid}", namespace, locale)
        detail = request_json(url, headers=headers)
        return normalize_quest_record(detail, fallback_id=qid, fallback_name=fallback_name)

    records: list[dict[str, Any]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        future_map = {pool.submit(fetch_one, ref): ref for ref in refs}
        for i, fut in enumerate(concurrent.futures.as_completed(future_map), start=1):
            qid, _ = future_map[fut]
            try:
                rec = fut.result()
                records.append(rec)
            except Exception as err:  # Keep going on per-quest failures.
                sys.stderr.write(f"[warn] quest {qid} failed: {err}\n")

            if i % 250 == 0:
                print(f"  fetched {i}/{len(refs)} quests...")

    return records


def build_index_only_records(quest_refs: Iterable[Tuple[int, str]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for qid, name in quest_refs:
        records.append(
            {
                "id": qid,
                "name": name,
                "category": None,
                "area": None,
                "type": None,
                "minimum_level": None,
                "level": None,
                "is_daily": False,
                "is_weekly": False,
                "is_repeatable": False,
                "suggested_party_members": None,
                "experience": None,
            }
        )
    return records


def update_route_data_ids(route_data_path: str, records: list[dict[str, Any]]) -> Tuple[int, int]:
    if not os.path.exists(route_data_path):
        raise FileNotFoundError(f"Route data file not found: {route_data_path}")

    normalized_to_id: dict[str, int] = {}
    for rec in records:
        qid = rec.get("id")
        name = rec.get("name")
        if isinstance(qid, int) and qid > 0 and isinstance(name, str) and name:
            normalized_to_id[slugify_name(name)] = qid

    with open(route_data_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    entry_name: Optional[str] = None
    touched = 0
    unresolved = 0

    for idx, line in enumerate(lines):
        name_match = re.search(r'name\s*=\s*"([^"]+)"\s*,', line)
        if name_match:
            entry_name = name_match.group(1)
            continue

        id_match = re.search(r'^(\s*)id\s*=\s*(\d+)\s*,\s*$', line)
        if id_match:
            current_id = int(id_match.group(2))
            indent = id_match.group(1)
            if current_id == 0 and entry_name:
                resolved = normalized_to_id.get(slugify_name(entry_name))
                if resolved:
                    lines[idx] = f"{indent}id = {resolved},\n"
                    touched += 1
                else:
                    unresolved += 1

    if touched:
        with open(route_data_path, "w", encoding="utf-8") as f:
            f.writelines(lines)

    return touched, unresolved


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract Blizzard WoW quest data for QuestHUD")
    parser.add_argument("--region", default="eu", help="Region host prefix (us|eu|kr|tw)")
    parser.add_argument("--locale", default="en_GB", help="Locale, e.g. en_GB")
    parser.add_argument("--namespace", default="static-eu", help="Game Data namespace, e.g. static-eu")
    parser.add_argument("--client-id", default=os.getenv("BLIZZARD_CLIENT_ID"), help="Blizzard API client ID")
    parser.add_argument("--client-secret", default=os.getenv("BLIZZARD_CLIENT_SECRET"), help="Blizzard API client secret")
    parser.add_argument("--details", action="store_true", help="Fetch per-quest detail endpoints")
    parser.add_argument("--workers", type=int, default=8, help="Parallel workers used with --details")
    parser.add_argument("--max-quests", type=int, default=0, help="Limit number of quests fetched (0 = all)")
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="Return success even when no quests were extracted",
    )
    parser.add_argument(
        "--out-json",
        default="QuestHUD/tools/generated/quest_data.json",
        help="Output path for JSON",
    )
    parser.add_argument(
        "--out-lua",
        default="QuestHUD/QuestHUD_QuestAPIData.lua",
        help="Output path for addon Lua table",
    )
    parser.add_argument(
        "--update-route-data",
        default="",
        help="Optional path to QuestHUD_RouteData.lua for auto-filling id = 0 entries",
    )
    return parser.parse_args()


def ensure_parent(path: str) -> None:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)


def main() -> int:
    args = parse_args()
    args.region = args.region.lower()

    if not args.client_id or not args.client_secret:
        sys.stderr.write("error: missing credentials. Set BLIZZARD_CLIENT_ID and BLIZZARD_CLIENT_SECRET or pass --client-id/--client-secret.\n")
        return 2

    if not args.namespace.startswith(("static-", "dynamic-")):
        sys.stderr.write("warning: namespace usually starts with static- or dynamic- for Game Data APIs.\n")

    print("Getting OAuth token...")
    token = get_access_token(args.region, args.client_id, args.client_secret)

    print("Fetching quest index...")
    quest_refs = read_quest_index(args.region, token, args.namespace, args.locale)
    if args.max_quests and args.max_quests > 0:
        quest_refs = quest_refs[: args.max_quests]

    print(f"Quest refs loaded: {len(quest_refs)}")

    if args.details:
        print("Fetching quest details...")
        records = fetch_quest_details(
            args.region,
            token,
            args.namespace,
            args.locale,
            quest_refs,
            workers=max(1, args.workers),
        )
    else:
        print("Building index-only records (use --details for richer fields)...")
        records = build_index_only_records(quest_refs)

    # Keep deterministic output order.
    records.sort(key=lambda r: int(r.get("id", 0)))

    if len(records) == 0 and not args.allow_empty:
        sys.stderr.write(
            "error: zero quests extracted; use --allow-empty to continue writing empty output files.\n"
        )
        return 3

    metadata = {
        "generated_at": now_utc_iso(),
        "region": args.region,
        "namespace": args.namespace,
        "locale": args.locale,
        "quest_count": len(records),
        "details_enabled": bool(args.details),
    }

    ensure_parent(args.out_json)
    ensure_parent(args.out_lua)

    payload = {
        "metadata": metadata,
        "quests": records,
    }

    write_json(args.out_json, payload)
    write_lua(args.out_lua, metadata, records)

    print(f"Wrote JSON: {args.out_json}")
    print(f"Wrote Lua:  {args.out_lua}")

    if args.update_route_data:
        print(f"Updating route data IDs in: {args.update_route_data}")
        touched, unresolved = update_route_data_ids(args.update_route_data, records)
        print(f"Route IDs updated: {touched}")
        print(f"Route entries still unresolved: {unresolved}")

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
