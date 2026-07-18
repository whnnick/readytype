#!/usr/bin/env python3

import argparse
import concurrent.futures
import datetime as dt
import json
import math
import pathlib
import time
import urllib.parse
import urllib.request
import urllib.error
from typing import Dict, List, Optional, Tuple

from opencc import OpenCC


USER_AGENT = "ReadyTypeVocabulary/1.0 (https://github.com/whnnick/readytype)"
PAGEVIEWS_URL = "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/zh.wikipedia/all-access/{year}/{month}/{day}"
PROJECTS = ("zh.wikipedia.org", "en.wikipedia.org")
WIKIDATA_URL = "https://www.wikidata.org/w/api.php"
IGNORED_TITLES = {"Main_Page", "Wikipedia", "Special:Search", "-"}
ALLOWED_TYPES = {
    "Q5": ("person", ["chat", "document"]),
    "Q11424": ("movie", ["chat", "document"]),
    "Q5398426": ("television", ["chat"]),
    "Q7889": ("game", ["chat", "technical"]),
    "Q7397": ("software", ["technical", "aiTool"]),
    "Q4830453": ("company", ["chat", "email", "document"]),
    "Q43229": ("organization", ["chat", "email", "document"]),
    "Q16510064": ("sports", ["chat"]),
    "Q134556": ("music", ["chat"]),
    "Q482994": ("music", ["chat"]),
}
CATEGORY_LIMITS = {
    "person": 80,
    "movie": 100,
    "television": 80,
    "software": 80,
    "game": 60,
    "company": 60,
    "organization": 40,
    "sports": 40,
    "music": 60,
}
PROJECT_LIMIT = 250
SIMPLIFIED_CHINESE = OpenCC("t2s")


def safe_public_label(value: str) -> bool:
    if not value or len(value) > 80 or any(character in value for character in "\r\n\t"):
        return False
    compact = "".join(value.split())
    if len(compact) < 3:
        return False
    is_cjk_only = all(
        "\u3400" <= character <= "\u9fff" or "\u3040" <= character <= "\u30ff" or "\uac00" <= character <= "\ud7af"
        for character in compact
    )
    return not is_cjk_only or len(compact) >= 3


def request_json(url: str, params: Optional[Dict[str, str]] = None) -> dict:
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("unreachable")


def daily_top(day: dt.date, project: str) -> Dict[str, int]:
    url = PAGEVIEWS_URL.replace("zh.wikipedia", project.removesuffix(".org"))
    resolved_url = url.format(year=day.year, month=f"{day.month:02d}", day=f"{day.day:02d}")
    try:
        payload = request_json(resolved_url)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return {}
        raise RuntimeError(f"Pageviews request failed for {project} on {day}: HTTP {error.code}") from error
    articles = payload.get("items", [{}])[0].get("articles", [])
    return {
        f"{project}|{item['article']}": int(item["views"])
        for item in articles[:500]
        if valid_title(item.get("article", ""))
    }


def valid_title(title: str) -> bool:
    decoded = urllib.parse.unquote(title).replace("_", " ").strip()
    return bool(decoded) and title not in IGNORED_TITLES and ":" not in decoded and not decoded.startswith(("List of ", "列表"))


def chunks(values: List[str], size: int):
    for index in range(0, len(values), size):
        yield values[index:index + size]


def wikidata_ids(titles: List[str]) -> Dict[str, str]:
    result: Dict[str, str] = {}
    for project in PROJECTS:
        project_titles = [value.split("|", 1)[1] for value in titles if value.startswith(f"{project}|")]
        for batch in chunks(project_titles, 40):
            payload = request_json(f"https://{project}/w/api.php", {
                "action": "query", "format": "json", "formatversion": "2", "redirects": "1",
                "prop": "pageprops", "ppprop": "wikibase_item", "titles": "|".join(batch),
            })
            normalized = {item["to"]: item["from"] for item in payload.get("query", {}).get("normalized", [])}
            redirects = {item["to"]: normalized.get(item["from"], item["from"]) for item in payload.get("query", {}).get("redirects", [])}
            for page in payload.get("query", {}).get("pages", []):
                item_id = page.get("pageprops", {}).get("wikibase_item")
                title = page.get("title")
                if item_id and title:
                    source_title = redirects.get(title, normalized.get(title, title)).replace(" ", "_")
                    result[f"{project}|{source_title}"] = item_id
    return result


def entity_terms(ids: List[str], metrics: Dict[str, Tuple[int, int, float, int]], title_by_id: Dict[str, str], day: dt.date) -> List[dict]:
    terms: List[dict] = []
    expires_at = dt.datetime.combine(day + dt.timedelta(days=15), dt.time(), tzinfo=dt.timezone.utc).isoformat().replace("+00:00", "Z")
    for batch in chunks(ids, 40):
        payload = request_json(WIKIDATA_URL, {
            "action": "wbgetentities", "format": "json", "ids": "|".join(batch),
            "props": "labels|aliases|claims", "languages": "zh-hans|zh|en",
        })
        for item_id, entity in payload.get("entities", {}).items():
            type_ids = {
                claim.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id")
                for claim in entity.get("claims", {}).get("P31", [])
            }
            matched = next((details for value, details in ALLOWED_TYPES.items() if value in type_ids), None)
            if not matched:
                continue
            labels = entity.get("labels", {})
            label = next((labels[key]["value"].strip() for key in ("zh-hans", "zh", "en") if key in labels), "")
            label = SIMPLIFIED_CHINESE.convert(label)
            if not safe_public_label(label):
                continue
            aliases = []
            for language in ("zh-hans", "zh", "en"):
                for alias in entity.get("aliases", {}).get(language, []):
                    value = SIMPLIFIED_CHINESE.convert(alias.get("value", "").strip())
                    if value and value.casefold() != label.casefold() and len(value) <= 80 and value not in aliases:
                        aliases.append(value)
            aliases.sort(key=str.casefold)
            views, active_days, trend, rank = metrics[title_by_id[item_id]]
            rank_score = 25.0 * max(0.0, 1.0 - (rank - 1) / 499.0)
            trend_score = min(15.0, math.log2(max(trend, 1.0)) * 5.0)
            weight = min(100.0, 45.0 + rank_score + trend_score + min(10.0, active_days))
            category, scopes = matched
            terms.append({
                "aliases": aliases[:8], "category": category, "expiresAt": expires_at,
                "scopes": scopes, "sourceID": f"wikidata:{item_id}", "value": label,
                "weight": round(weight, 2), "_project": title_by_id[item_id].split("|", 1)[0],
            })
    unique: Dict[str, dict] = {}
    for term in terms:
        key = "".join(term["value"].casefold().split())
        if key not in unique or term["weight"] > unique[key]["weight"]:
            unique[key] = term
    selected = []
    category_counts = {category: 0 for category in CATEGORY_LIMITS}
    project_counts = {project: 0 for project in PROJECTS}
    for term in sorted(unique.values(), key=lambda item: (-item["weight"], item["value"])):
        category = term["category"]
        project = term.pop("_project")
        if category_counts[category] >= CATEGORY_LIMITS[category] or project_counts[project] >= PROJECT_LIMIT:
            continue
        category_counts[category] += 1
        project_counts[project] += 1
        selected.append(term)
        if len(selected) == 500:
            break
    return selected


def build_pack(day: dt.date) -> dict:
    days = [day - dt.timedelta(days=offset) for offset in range(28)]
    jobs = [(value, project) for value in days for project in PROJECTS]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(lambda job: daily_top(*job), jobs))
    snapshots = {value: {} for value in days}
    for (value, _), result in zip(jobs, results):
        snapshots[value].update(result)
    daily = [(value, snapshots[value]) for value in days]
    if any(not any(key.startswith(f"{project}|") for key in snapshots[day]) for project in PROJECTS):
        raise RuntimeError(f"Target-day Pageviews data is incomplete for {day}")
    for project in PROJECTS:
        available_days = sum(
            any(key.startswith(f"{project}|") for key in snapshot)
            for snapshot in snapshots.values()
        )
        if available_days < 24:
            raise RuntimeError(f"Only {available_days} of 28 baseline days are available for {project}")
    current_titles = list(daily[0][1].keys())
    metrics: Dict[str, Tuple[int, int, float, int]] = {}
    ranks = {project: 0 for project in PROJECTS}
    for title in current_titles:
        project = title.split("|", 1)[0]
        ranks[project] += 1
        recent = [values.get(title, 0) for _, values in daily[:7]]
        baseline = [values.get(title, 0) for _, values in daily[7:]]
        recent_sum = sum(recent)
        active_days = sum(value > 0 for value in recent)
        baseline_daily = sum(baseline) / max(len(baseline), 1)
        trend = (recent_sum / 7) / max(baseline_daily, 1)
        if active_days >= 2 or trend >= 2.0:
            metrics[title] = (recent_sum, active_days, trend, ranks[project])
    ids_by_title = wikidata_ids(list(metrics.keys()))
    title_by_id: Dict[str, str] = {}
    for title, item_id in sorted(ids_by_title.items()):
        if item_id not in title_by_id or metrics[title] > metrics[title_by_id[item_id]]:
            title_by_id[item_id] = title
    terms = entity_terms(sorted(title_by_id), metrics, title_by_id, day)
    if not terms:
        raise RuntimeError("No eligible vocabulary terms were generated")
    return {"packVersion": day.strftime("%Y.%m.%d"), "terms": terms}


def latest_complete_day(start: dt.date) -> dt.date:
    for offset in range(4):
        candidate = start - dt.timedelta(days=offset)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            snapshots = list(executor.map(lambda project: daily_top(candidate, project), PROJECTS))
        if all(snapshots):
            return candidate
    raise RuntimeError("No complete bilingual Pageviews day is available within the last four days")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", help="Last complete UTC date in YYYY-MM-DD")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    today = dt.datetime.now(dt.timezone.utc).date()
    day = dt.date.fromisoformat(args.date) if args.date else latest_complete_day(today - dt.timedelta(days=1))
    if day >= today:
        parser.error("source date must be a completed UTC day")
    output = pathlib.Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(build_pack(day), ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
