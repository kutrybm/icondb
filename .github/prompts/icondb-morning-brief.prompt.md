---
name: "IconDB Morning Brief"
description: "Run the bounded 08:00 IconDB morning brief, including Jira changes made since the prior daily control, without full Jira inventory or CPS/PDCA mutation."
agent: "agent"
---

Run the 08:00 IconDB morning brief for today.

## Boundary

- Before the first Jira MCP call, run a read-only Docker preflight for the configured `desktop-linux` engine. If Docker is installed but not running, attempt to start Docker Desktop once, report that the run is paused, and stop before creating Jira-dependent outputs. Ask the user to rerun the brief after Docker reports that the engine is running and VS Code has been reloaded. If Docker cannot be started, give the exact manual recovery step. Do not misclassify a stopped Docker engine as a Jira authentication failure.
- Use the newest mechanically validated and Markdown-safe Power Automate evidence available under `.local/power-automate/` plus the prior control close.
- Review overnight evidence, today's calendar, existing unsent IconDB drafts, Sent Items state, and open `[IconDB]` Microsoft To Do actions.
- Use Jira MCP to retrieve Icon DB issues updated since the prior successful 14:00 daily-control watermark, including overnight comments from the US working day. Capture changed status, assignee, dates, blockers, dependencies, and material comments.
- Do not retrieve the complete Jira inventory or compare every Jira issue with CPS. Include older Jira keys only when overnight evidence references them.
- Do not open, edit, or regenerate the CPS or PDCA. Do not infer schedule changes.
- Do not send mail, change Jira, or accept or decline meetings.

## Output

1. State the Outlook and Jira watermarks and what changed since the prior successful control.
2. List the three most important actions before noon.
3. List meetings needing preparation and any availability conflict using `busyOnly` details only.
4. Create or update only European-timing unsent drafts and user-owned To Do actions that are due before the midday checkpoint.
5. Recheck the relevant conversation head and Sent Items before changing a draft.
6. Add overnight developer comments and candidate questions to a read-only handoff register. Do not prepare a developer-facing follow-up draft in the morning.
7. Mark any Jira/CPS contradiction or possible schedule change as `defer to 14:00 daily control`.

End with `brief complete`, `brief complete - control escalation queued`, or `brief incomplete - evidence unavailable`.
