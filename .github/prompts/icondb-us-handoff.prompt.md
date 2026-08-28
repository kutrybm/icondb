---
name: "IconDB US Handoff"
description: "Run the bounded 15:00 IconDB US handoff from changes since the daily control; prepare US-timing drafts and tomorrow's handoff without routine CPS/PDCA mutation."
agent: "agent"
---

Run the 15:00 IconDB US handoff for today.

## Boundary

- Start from the completed 14:00 daily-control watermark and inspect only later validated evidence, Sent Items, relevant draft state, and changed `[IconDB]` To Do state.
- Prepare US-timing communication and tomorrow's handoff; do not repeat the daily Jira inventory.
- Do not reopen or mutate CPS/PDCA unless a new explicit schedule-changing event arrived after the control. If one did, stop and request an exceptional control rerun rather than changing the workbook in this prompt.
- Do not send mail, change Jira, or accept or decline meetings.

## Output

1. List changes since the daily control and unresolved decisions needing US input.
2. Create or update unsent US-timing drafts after rechecking conversation heads and Sent Items.
3. Reconcile user-owned To Do actions for the remainder of today and the next business morning.
4. Record what should become the next morning brief's prior-day close.
5. Flag any post-control schedule change as `exceptional daily-control rerun required`.

End with `handoff complete`, `handoff complete - exceptional control queued`, or `handoff incomplete - evidence unavailable`.
