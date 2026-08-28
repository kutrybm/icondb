---
name: "IconDB Midday Checkpoint"
description: "Run the bounded 12:00 IconDB checkpoint using only evidence added since the morning watermark; update immediate actions and drafts without CPS/PDCA mutation."
agent: "agent"
---

Run the 12:00 IconDB checkpoint for today.

## Boundary

- Start from the morning brief watermark and inspect only newly validated evidence, changed meeting state, Sent Items, relevant draft state, and changed `[IconDB]` To Do state.
- Do not repeat sources that have not changed since the morning brief.
- Refresh only Jira keys in the morning handoff register or introduced by new evidence. Do not retrieve the complete Jira inventory.
- Do not open, edit, or regenerate the CPS or PDCA.
- Consolidate candidate developer questions, but do not create a developer-facing follow-up draft before the 14:00 Jira/CPS reconciliation.
- Do not send mail, change Jira, or accept or decline meetings.

## Output

1. List material changes since the morning brief and explicitly state when there are none.
2. Reconcile meeting outcomes, changed commitments, and immediate actions before 14:00.
3. Identify drafts that are obsolete because a reply was sent or the conversation head changed.
4. Create or update only user-owned actions due before the daily control.
5. Produce a deduplicated candidate developer-question register with Jira key, overnight change, question, evidence needed, and delivery impact.
6. Queue schedule, dependency, Jira/CPS, or PDCA implications for the 14:00 daily control with their exact source IDs.

End with `checkpoint complete`, `checkpoint complete - control changes queued`, or `checkpoint incomplete - evidence unavailable`.
