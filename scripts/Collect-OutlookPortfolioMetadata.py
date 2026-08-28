from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


DRAFT_FOLDER = 16
TASK_FOLDER = 13
TASK_STATUSES = {
    0: "notStarted",
    1: "inProgress",
    2: "completed",
    3: "waiting",
    4: "deferred",
}
ROOT_FIELDS = {
    "schemaVersion",
    "run",
    "window",
    "coverage",
    "messages",
    "calendarEvents",
    "drafts",
    "tasks",
    "routes",
}
PROJECT_TERMS = {
    "icondb": (
        "icondb",
        "icon db",
        "icon database",
        "icon",
        "icons",
        "aed",
        "bps",
        "canvas",
        "graphics library",
        "graphical element",
        "graphical elements",
    ),
    "phc-global": (
        "phc",
        "phc global",
        "phc eu",
        "phc la",
        "phc na",
        "phc ama",
        "phc apac",
        "personal health care",
        "personal healthcare",
    ),
    "ai-translation": (
        "ai translation",
        "ai integration",
        "ai translation integration",
        "translation integration",
        "translation intergration",
        "translation",
        "translations",
        "mace",
        "transperfect",
        "local copy",
        "local copies",
        "lc",
    ),
}


class CollectionError(RuntimeError):
    pass


def parse_datetime(value: Any, context: str) -> datetime:
    if isinstance(value, datetime):
        parsed = value
    elif isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as exc:
            raise CollectionError(f"{context} is not a valid ISO 8601 date-time") from exc
    else:
        raise CollectionError(f"{context} is not a date-time")
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise CollectionError(f"{context} has no UTC offset")
    return parsed


def iso_utc(value: Any, context: str) -> str:
    parsed = parse_datetime(value, context).astimezone(timezone.utc)
    return parsed.isoformat(timespec="microseconds").replace("+00:00", "Z")


def opaque_id(kind: str, value: Any) -> str:
    source = str(value or "").strip()
    if not source:
        raise CollectionError(f"{kind} item has no stable Outlook identity")
    digest = hashlib.sha256(f"{kind}\0{source}".encode("utf-8")).hexdigest()
    return f"{kind}:{digest}"


def required_property(item: Any, name: str, context: str) -> Any:
    try:
        value = getattr(item, name)
    except Exception as exc:
        raise CollectionError(f"{context} cannot read required property {name}") from exc
    if value is None:
        raise CollectionError(f"{context} required property {name} is null")
    return value


def collection_count(value: Any, context: str) -> int:
    try:
        count = int(value.Count)
    except Exception as exc:
        raise CollectionError(f"{context} count is unavailable") from exc
    if count < 0:
        raise CollectionError(f"{context} count is invalid")
    return count


def normalized_subject(value: Any) -> str:
    subject = str(value or "").strip()
    return subject if subject else "(no subject)"


def normalize_draft(item: Any, ordinal: int) -> dict[str, Any]:
    context = f"draft item {ordinal}"
    result: dict[str, Any] = {
        "stableId": opaque_id("draft", required_property(item, "EntryID", context)),
        "lastModifiedAt": iso_utc(
            required_property(item, "LastModificationTime", context),
            f"{context} LastModificationTime",
        ),
        "subject": normalized_subject(required_property(item, "Subject", context)),
        "recipientCount": collection_count(
            required_property(item, "Recipients", context), f"{context} recipients"
        ),
        "attachmentCount": collection_count(
            required_property(item, "Attachments", context), f"{context} attachments"
        ),
    }
    conversation_id = required_property(item, "ConversationID", context)
    if str(conversation_id).strip():
        result["conversationId"] = opaque_id("conversation", conversation_id)
    return result


def normalize_task(item: Any, ordinal: int) -> dict[str, Any]:
    context = f"task item {ordinal}"
    try:
        status = TASK_STATUSES[int(required_property(item, "Status", context))]
    except (KeyError, TypeError, ValueError) as exc:
        raise CollectionError(f"{context} has an unsupported status") from exc
    result: dict[str, Any] = {
        "stableId": opaque_id("task", required_property(item, "EntryID", context)),
        "lastModifiedAt": iso_utc(
            required_property(item, "LastModificationTime", context),
            f"{context} LastModificationTime",
        ),
        "subject": normalized_subject(required_property(item, "Subject", context)),
        "status": status,
    }
    due_date = required_property(item, "DueDate", context)
    if isinstance(due_date, datetime) and due_date.year < 4500:
        result["dueAt"] = iso_utc(due_date, f"{context} DueDate")
    return result


def collect_items(
    items: Any,
    kind: str,
    window_start: datetime,
    window_end: datetime,
) -> tuple[int, list[dict[str, Any]]]:
    source_count = collection_count(items, f"{kind} folder")
    retained: list[dict[str, Any]] = []
    normalizer = normalize_draft if kind == "draft" else normalize_task
    for ordinal in range(1, source_count + 1):
        try:
            item = items.Item(ordinal)
        except Exception as exc:
            raise CollectionError(f"{kind} item {ordinal} is inaccessible") from exc
        normalized = normalizer(item, ordinal)
        modified = parse_datetime(normalized["lastModifiedAt"], f"{kind} item {ordinal} lastModifiedAt")
        if window_start <= modified <= window_end:
            retained.append(normalized)
    stable_ids = [item["stableId"] for item in retained]
    if len(stable_ids) != len(set(stable_ids)):
        raise CollectionError(f"duplicate {kind} stable identity")
    return source_count, sorted(retained, key=lambda item: item["stableId"])


def collect_stable_items(
    items: Any,
    kind: str,
    window_start: datetime,
    window_end: datetime,
) -> tuple[int, list[dict[str, Any]]]:
    first = collect_items(items, kind, window_start, window_end)
    second = collect_items(items, kind, window_start, window_end)
    if first != second:
        raise CollectionError(f"{kind} folder changed during collection")
    return second


def subject_matches_term(subject: str, term: str) -> bool:
    words = term.split()
    pattern = r"(?<!\w)" + r"[\s_-]+".join(re.escape(word) for word in words) + r"(?!\w)"
    return re.search(pattern, subject, flags=re.IGNORECASE) is not None


def route_for(item: dict[str, Any]) -> dict[str, Any]:
    subject = item["subject"].casefold()
    projects = sorted(
        project
        for project, terms in PROJECT_TERMS.items()
        if any(subject_matches_term(subject, term) for term in terms)
    )
    if len(projects) == 1:
        disposition = "routed"
        reason = f"subject-term:{projects[0]}"
    elif len(projects) > 1:
        disposition = "ambiguous"
        reason = "multiple-project-subject-terms"
    else:
        disposition = "unmatched"
        reason = "no-approved-subject-term"
    return {
        "stableId": item["stableId"],
        "projects": projects,
        "disposition": disposition,
        "reasonCodes": [reason],
    }


def validate_cloud_projection(projection: dict[str, Any]) -> tuple[datetime, datetime]:
    if set(projection) != ROOT_FIELDS:
        raise CollectionError("cloud projection root fields do not match the version 1.0 contract")
    if projection.get("schemaVersion") != "1.0":
        raise CollectionError("cloud projection schemaVersion must be 1.0")
    if projection.get("drafts") != [] or projection.get("tasks") != []:
        raise CollectionError("cloud projection must not pre-populate drafts or tasks")
    coverage = projection.get("coverage")
    if not isinstance(coverage, dict):
        raise CollectionError("cloud projection coverage is missing")
    for source in ("inbox", "sentItems", "calendar"):
        if not isinstance(coverage.get(source), dict) or coverage[source].get("complete") is not True:
            raise CollectionError(f"cloud projection {source} coverage is incomplete")
    for source in ("drafts", "tasks"):
        source_coverage = coverage.get(source)
        if not isinstance(source_coverage, dict) or source_coverage.get("complete") is not False:
            raise CollectionError(f"cloud projection {source} coverage must be explicitly incomplete")
        if source_coverage.get("sourceCount") != 0 or source_coverage.get("retainedCount") != 0:
            raise CollectionError(f"cloud projection {source} counts must be zero")
    window = projection.get("window")
    if not isinstance(window, dict):
        raise CollectionError("cloud projection window is missing")
    window_start = parse_datetime(window.get("windowStart"), "projection.window.windowStart")
    window_end = parse_datetime(window.get("windowEnd"), "projection.window.windowEnd")
    if window_end <= window_start:
        raise CollectionError("projection windowEnd must be after windowStart")
    return window_start, window_end


def finalize_projection(
    projection: dict[str, Any],
    draft_items: Any,
    task_items: Any,
) -> dict[str, Any]:
    window_start, window_end = validate_cloud_projection(projection)
    draft_source_count, drafts = collect_stable_items(
        draft_items, "draft", window_start, window_end
    )
    task_source_count, tasks = collect_stable_items(task_items, "task", window_start, window_end)
    result = json.loads(json.dumps(projection))
    result["drafts"] = drafts
    result["tasks"] = tasks
    result["coverage"]["drafts"] = {
        "complete": True,
        "sourceCount": draft_source_count,
        "retainedCount": len(drafts),
    }
    result["coverage"]["tasks"] = {
        "complete": True,
        "sourceCount": task_source_count,
        "retainedCount": len(tasks),
    }
    existing_routes = result["routes"]
    if not isinstance(existing_routes, list):
        raise CollectionError("cloud projection routes must be an array")
    message_by_id = {item["stableId"]: item for item in result["messages"]}
    routes = []
    for route in existing_routes:
        if (
            isinstance(route, dict)
            and route.get("stableId") in message_by_id
            and route.get("disposition") == "unmatched"
            and route.get("projects") == []
            and route.get("reasonCodes") == ["neutral-cloud-route"]
        ):
            routes.append(route_for(message_by_id[route["stableId"]]))
        else:
            routes.append(route)
    routes += [route_for(item) for item in drafts + tasks]
    route_ids = [route.get("stableId") for route in routes if isinstance(route, dict)]
    if len(route_ids) != len(routes) or len(route_ids) != len(set(route_ids)):
        raise CollectionError("projection contains duplicate or malformed routes")
    result["routes"] = sorted(routes, key=lambda route: route["stableId"])
    return result


def outlook_folders() -> tuple[Any, Any]:
    try:
        import win32com.client

        outlook = win32com.client.Dispatch("Outlook.Application")
        namespace = outlook.GetNamespace("MAPI")
        return (
            namespace.GetDefaultFolder(DRAFT_FOLDER).Items,
            namespace.GetDefaultFolder(TASK_FOLDER).Items,
        )
    except Exception as exc:
        raise CollectionError("Outlook Drafts or Tasks folder is unavailable") from exc


def atomic_write_json(value: dict[str, Any], output_path: Path) -> None:
    output_path = output_path.resolve()
    temporary_path = Path(f"{output_path}.building")
    if output_path.exists():
        raise CollectionError(f"output already exists: {output_path}")
    if temporary_path.exists():
        raise CollectionError(f"temporary output already exists: {temporary_path}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with temporary_path.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, ensure_ascii=True, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        if output_path.exists():
            raise CollectionError(f"output already exists: {output_path}")
        os.rename(temporary_path, output_path)
    finally:
        try:
            temporary_path.unlink()
        except FileNotFoundError:
            pass


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CollectionError(f"cannot read cloud projection: {path}") from exc
    if not isinstance(value, dict):
        raise CollectionError("cloud projection root must be an object")
    return value


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Finalize portfolio evidence with Outlook metadata.")
    parser.add_argument("--cloud-projection", required=True, type=Path)
    parser.add_argument("--output-projection", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        projection = load_json(args.cloud_projection)
        draft_items, task_items = outlook_folders()
        completed = finalize_projection(projection, draft_items, task_items)
        atomic_write_json(completed, args.output_projection)
        print(f"Completed privacy-minimized projection: {args.output_projection.resolve()}")
        return 0
    except (CollectionError, OSError, UnicodeError) as exc:
        print(f"Outlook metadata collection failed: {exc}", file=__import__("sys").stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
