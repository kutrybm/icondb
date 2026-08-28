from __future__ import annotations

import importlib.util
import json
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace


MODULE_PATH = Path(__file__).with_name("Collect-OutlookPortfolioMetadata.py")
SPEC = importlib.util.spec_from_file_location("outlook_metadata", MODULE_PATH)
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class Collection:
    def __init__(self, values):
        self.values = list(values)
        self.Count = len(self.values)

    def Item(self, ordinal):
        return self.values[ordinal - 1]


class DriftingCollection:
    def __init__(self, values, added):
        self.values = list(values)
        self.added = added
        self.reads = 0

    @property
    def Count(self):
        self.reads += 1
        if self.reads == 2:
            self.values.append(self.added)
        return len(self.values)

    def Item(self, ordinal):
        return self.values[ordinal - 1]


def projection(start, end):
    coverage = {
        "inbox": {"complete": True, "sourceCount": 0, "retainedCount": 0},
        "sentItems": {"complete": True, "sourceCount": 0, "retainedCount": 0},
        "calendar": {"complete": True, "sourceCount": 0, "retainedCount": 0},
        "drafts": {"complete": False, "sourceCount": 0, "retainedCount": 0},
        "tasks": {"complete": False, "sourceCount": 0, "retainedCount": 0},
    }
    return {
        "schemaVersion": "1.0",
        "run": {},
        "window": {"windowStart": start.isoformat(), "windowEnd": end.isoformat()},
        "coverage": coverage,
        "messages": [],
        "calendarEvents": [],
        "drafts": [],
        "tasks": [],
        "routes": [],
    }


def draft(entry_id, modified, subject="IconDB draft"):
    return SimpleNamespace(
        EntryID=entry_id,
        LastModificationTime=modified,
        Subject=subject,
        ConversationID="private-conversation-id",
        Recipients=SimpleNamespace(Count=2),
        Attachments=SimpleNamespace(Count=1),
    )


def task(entry_id, modified, status=0, subject="Other work", due=None):
    return SimpleNamespace(
        EntryID=entry_id,
        LastModificationTime=modified,
        Subject=subject,
        Status=status,
        DueDate=due or datetime(4501, 1, 1, tzinfo=timezone.utc),
    )


def message(stable_id, subject):
    return {
        "stableId": stable_id,
        "folder": "inbox",
        "occurredAt": "2026-08-27T12:00:00Z",
        "subject": subject,
        "counterparty": "opaque-counterparty",
        "bodyPreview": "",
        "conversationId": "opaque-conversation",
        "importance": "normal",
    }


def expect_failure(action, text):
    try:
        action()
    except module.CollectionError as exc:
        assert text in str(exc), str(exc)
    else:
        raise AssertionError(f"expected failure containing {text!r}")


def run():
    now = datetime.now(timezone.utc)
    start = now - timedelta(hours=1)
    end = now + timedelta(hours=1)
    complete = module.finalize_projection(
        projection(start, end),
        Collection([draft("raw-draft-id", now), draft("old-id", start - timedelta(seconds=1))]),
        Collection([task("raw-task-id", now, 1, "AI translation", now + timedelta(days=1))]),
    )
    assert complete["coverage"]["drafts"] == {
        "complete": True,
        "sourceCount": 2,
        "retainedCount": 1,
    }
    assert complete["coverage"]["tasks"]["retainedCount"] == 1
    assert complete["tasks"][0]["status"] == "inProgress"
    assert complete["tasks"][0]["dueAt"].endswith("Z")
    serialized = json.dumps(complete)
    for private_value in ("raw-draft-id", "raw-task-id", "private-conversation-id"):
        assert private_value not in serialized
    assert set(complete["drafts"][0]) == {
        "stableId",
        "lastModifiedAt",
        "subject",
        "conversationId",
        "recipientCount",
        "attachmentCount",
    }
    assert set(complete["tasks"][0]) == {
        "stableId",
        "lastModifiedAt",
        "subject",
        "status",
        "dueAt",
    }
    dispositions = {route["stableId"]: route["disposition"] for route in complete["routes"]}
    assert dispositions[complete["drafts"][0]["stableId"]] == "routed"
    assert dispositions[complete["tasks"][0]["stableId"]] == "routed"

    routing_cases = {
        "Icon review": ["icondb"],
        "Icons release": ["icondb"],
        "AED readiness": ["icondb"],
        "BPS dependency": ["icondb"],
        "Canvas status": ["icondb"],
        "Graphics-library migration": ["icondb"],
        "Graphical element approval": ["icondb"],
        "Graphical_elements inventory": ["icondb"],
        "PHC": ["phc-global"],
        "PHC EU launch": ["phc-global"],
        "phc-la readiness": ["phc-global"],
        "PHC NA status": ["phc-global"],
        "PHC AMA control": ["phc-global"],
        "PHC_APAC update": ["phc-global"],
        "Personal Health Care review": ["phc-global"],
        "Personal-Healthcare planning": ["phc-global"],
        "AI translation integration": ["ai-translation"],
        "AI integration checkpoint": ["ai-translation"],
        "translation intergration": ["ai-translation"],
        "Translations status": ["ai-translation"],
        "MACE delivery": ["ai-translation"],
        "TransPerfect follow-up": ["ai-translation"],
        "local_copy package": ["ai-translation"],
        "LC validation": ["ai-translation"],
        "PHC translation dependency": ["ai-translation", "phc-global"],
        "Calculation update": [],
        "Bespoke planning session": [],
        "Unrelated work": [],
    }
    for subject, expected_projects in routing_cases.items():
        route = module.route_for({"stableId": subject, "subject": subject})
        assert route["projects"] == expected_projects, (subject, route)
        expected_disposition = (
            "unmatched"
            if not expected_projects
            else "ambiguous"
            if len(expected_projects) > 1
            else "routed"
        )
        assert route["disposition"] == expected_disposition, (subject, route)

    mail_projection = projection(start, end)
    mail_projection["messages"] = [message("mail:phc", "PHC EU launch")]
    mail_projection["coverage"]["inbox"] = {
        "complete": True,
        "sourceCount": 1,
        "retainedCount": 1,
    }
    mail_projection["routes"] = [
        {
            "stableId": "mail:phc",
            "projects": [],
            "disposition": "unmatched",
            "reasonCodes": ["neutral-cloud-route"],
        },
        {
            "stableId": "calendar:busy",
            "projects": [],
            "disposition": "unmatched",
            "reasonCodes": ["busy-only-neutral-route"],
        },
    ]
    completed_mail = module.finalize_projection(mail_projection, Collection([]), Collection([]))
    mail_route = next(route for route in completed_mail["routes"] if route["stableId"] == "mail:phc")
    calendar_route = next(
        route for route in completed_mail["routes"] if route["stableId"] == "calendar:busy"
    )
    assert mail_route["projects"] == ["phc-global"]
    assert mail_route["disposition"] == "routed"
    assert calendar_route["reasonCodes"] == ["busy-only-neutral-route"]

    empty = module.finalize_projection(
        projection(start, end),
        Collection([draft("old-draft", start - timedelta(seconds=1))]),
        Collection([task("old-task", start - timedelta(seconds=1))]),
    )
    assert empty["drafts"] == [] and empty["tasks"] == []
    assert empty["coverage"]["drafts"] == {
        "complete": True,
        "sourceCount": 1,
        "retainedCount": 0,
    }
    boundaries = module.finalize_projection(
        projection(start, end),
        Collection([draft("at-start", start), draft("at-end", end)]),
        Collection([]),
    )
    assert len(boundaries["drafts"]) == 2

    for status_number, status_name in module.TASK_STATUSES.items():
        assert module.normalize_task(task(str(status_number), now, status_number), 1)["status"] == status_name

    expect_failure(
        lambda: module.finalize_projection(
            projection(start, end), Collection([draft("same", now), draft("same", now)]), Collection([])
        ),
        "duplicate draft stable identity",
    )
    expect_failure(
        lambda: module.finalize_projection(
            {**projection(start, end), "drafts": [{}]}, Collection([]), Collection([])
        ),
        "must not pre-populate",
    )
    incomplete = projection(start, end)
    incomplete["coverage"]["calendar"]["complete"] = False
    expect_failure(
        lambda: module.finalize_projection(incomplete, Collection([]), Collection([])),
        "calendar coverage is incomplete",
    )
    expect_failure(
        lambda: module.normalize_task(task("bad", now, 99), 1), "unsupported status"
    )
    expect_failure(
        lambda: module.normalize_draft(SimpleNamespace(), 1), "cannot read required property"
    )
    expect_failure(
        lambda: module.finalize_projection(
            projection(start, end),
            DriftingCollection([], draft("late-draft", now)),
            Collection([]),
        ),
        "draft folder changed during collection",
    )

    with tempfile.TemporaryDirectory(prefix="outlook-metadata-test-") as directory:
        output = Path(directory) / "projection.json"
        module.atomic_write_json(complete, output)
        original = output.read_bytes()
        expect_failure(lambda: module.atomic_write_json({}, output), "output already exists")
        assert output.read_bytes() == original
        assert not Path(f"{output}.building").exists()

    print("PASS: Outlook portfolio metadata collector suite completed.")


if __name__ == "__main__":
    run()
