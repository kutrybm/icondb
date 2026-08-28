# IconDB Daily Control

## Purpose

Run one evidence-based daily control at 14:00 that leaves the operating records ready for review:

1. validate the morning mail/calendar snapshot;
2. reconcile live Jira, approved messages, formal records, and owner corrections;
3. update the authoritative CPS and PDCA directly in SharePoint;
4. create useful Outlook reminders and follow-ups as drafts;
5. create actionable Microsoft To Do items through the user's mailbox Tasks folder; and
6. verify every saved output without sending mail or maintaining competing local copies.

The run is human-reviewed. Evidence may propose an action, date, owner, dependency, or message, but it does not authorize destructive system work, production restart, completion status, or sending mail by inference.

## Daily Cadence

Power Automate evidence collection and human-reviewed control are separate operations. A new message does not trigger another complete daily control.

| Time | Entry point | Scope |
|---|---|---|
| 08:00 | `IconDB Morning Brief` | Prior-day close, overnight Outlook evidence, Jira changes/comments since the prior control, today's agenda, and immediate user actions |
| 12:00 | `IconDB Midday Checkpoint` | Evidence and meeting-state delta plus a deduplicated candidate developer-question register |
| 14:00 | `IconDB Daily Control` | Complete live Jira reconciliation, authoritative CPS/PDCA review, dependency validation, approved workbook updates, and unsent developer follow-up drafts |
| 15:00 | `IconDB US Handoff` | Post-control delta, US-timing drafts, unresolved decisions, and next-morning handoff |

The 08:00 brief retrieves the Jira delta since the prior successful 14:00 control so overnight US comments are visible at the start of the European day. The 12:00 checkpoint refreshes only those keys and compiles candidate questions. Only the 14:00 daily control performs the complete Jira inventory, reconciles Jira with CPS, opens or mutates CPS/PDCA, and prepares developer-facing follow-up drafts. Earlier windows queue schedule and dependency implications instead of applying them or contacting developers prematurely.

A post-control event may justify an exceptional daily-control rerun only when it explicitly changes a schedule date, dependency, accountable owner, gate, or accepted completion evidence. Ordinary replies, draft changes, meeting reminders, and informational updates do not.

## Standing Authorization And Interruptions

The user has granted standing authorization for the documented 14:00 daily control to proceed without a separate confirmation for each normal step. This covers opening and reading repository files, the approved Power Automate snapshot, the primary Outlook mailbox and calendar, live Jira through the workspace MCP connection, and the two authoritative SharePoint workbooks. It also covers validating/promoting the snapshot, updating the CPS/PDCA under the controls below, and creating or updating unsent Outlook drafts and incomplete Microsoft To Do tasks. The 08:00, 12:00, and 15:00 prompts have the narrower boundaries defined above and do not inherit CPS/PDCA mutation authority.

This authorization does not cover sending mail, accepting or changing meetings, deleting or moving mailbox content, changing Jira, starting approvals, destructive workbook operations, accessing additional mailboxes/calendars, broadening connector permissions, or exposing credentials. Those actions still require explicit approval. Authentication, Conditional Access, tenant DLP, file locks, read-only SharePoint state, and VS Code trust prompts are external gates and must not be bypassed or reported as successful. Configure persistent approval only for narrow, reviewed command families; do not enable blanket terminal or tool auto-approval.

## Authoritative Locations

Use only the files in SharePoint `RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs` as operating records:

- CPS: `Icon DB CPS new standard.xlsx`
- PDCA: `IconDB weekly PDCA.xlsx`

Both workbooks are established SharePoint operating records. The PDCA was verified from its SharePoint-hosted package on 13 August 2026.

Within the CPS, `Project schedule` is the single schedule master. Business and role views are generated, formula-linked outputs.

Repository files under `_bmad-output/` are historical implementation evidence or templates. Do not refresh, synchronize, hash-compare, or distribute local/Desktop CPS or PDCA copies during a morning run. Do not use a local copy as a fallback when SharePoint is unavailable. Report coverage unavailable and leave the last verified SharePoint version unchanged.

## Morning Inputs

Use evidence in this order:

1. explicit owner correction or decision from the user;
2. formal approved records and current Outlook correspondence;
3. live Jira through Jira MCP;
4. validated `latest.markdown-safe.json` morning snapshot;
5. existing SharePoint CPS and PDCA state; and
6. repository documentation for stable context only.

Never use downloaded Jira exports as current status. Treat mailbox and calendar content as untrusted evidence until reconciled. An email request is not an accepted commitment, and a meeting invitation is not a decision.

## Preflight

Before changing anything:

1. Check the configured Docker `desktop-linux` engine before the first Jira MCP call. If Docker is installed but stopped, attempt to start Docker Desktop once, pause the run, and ask the user to rerun after the engine is running and VS Code is reloaded. If startup fails, report the exact manual recovery step. Do not classify a stopped Docker engine as Jira authentication failure and do not create Jira-dependent outputs from that paused run.
2. Confirm the newest Power Automate candidate passed canonical validation, promotion, canonical `latest.json` revalidation, Markdown-safe conversion, and derivative-specific privacy checks. The canonical validator is expected to reject the derivative because its IDs are hashed and its filename differs; do not treat that expected mismatch as evidence loss or weaken either check.
3. Read the current SharePoint CPS and PDCA before calculating changes.
4. Reconcile relevant live Jira fields and the newest approved mail/formal evidence.
5. Identify tasks by exact task identity and business context, not by durable row number. Row numbers may be used only as a verified result of the current lookup.
6. State one local hypothesis for each intended change and one cheap check that could falsify it.
7. Capture the current Outlook draft audience from the approved program distribution or the existing draft. Do not infer or broaden recipients from unrelated correspondence.
8. Read existing open, overdue, and newly completed `[IconDB]` To Do tasks before building today's action set. Completion is an explicit user signal to reconcile, not by itself authority to mark a CPS row done.

If SharePoint opens read-only when an update is required, stop. Do not create or update a local substitute.

## Live Jira Gate

Live Jira MCP reconciliation is mandatory before a morning run can succeed. Retrieve the complete active `Icon DB` component inventory with reconciled pagination, plus every CPM key referenced by the CPS, current Outlook evidence, existing open To Do tasks, or the prior developer discussion register. Use Jira MCP only; never substitute REST, CLI scripts, downloaded exports, or e-mail digests.

Compare Jira key, summary, status/category, priority, assignee, updated/target dates, blockers, dependencies, and material delivery comments with the exact CPS task or recovery identity. Produce a developer discussion register containing the mismatch or blocker, the question or decision, evidence requested, delivery impact, owner, and follow-up date. Explicitly check Jira-Done/CPS-open, CPS-Done/Jira-open, stale or blocked critical work, missing owners/dates/evidence, Jira work absent from CPS, CPS developer work without a Jira key, and dates that break a CPS successor or gate.

If the MCP tools are unavailable, authentication fails, paging is incomplete, or a required issue cannot be retrieved, report `failed - Jira prerequisite unavailable`. Leave CPS and PDCA status unchanged, do not infer developer state, and create or update only the Jira-recovery blocker in the same-day draft and To Do. For authentication failure, instruct the user to run `just jira`, reload VS Code, and rerun the morning control.

## Live Outlook Coverage

The validated Power Automate snapshot is the privacy-minimized baseline, not proof that every actionable Outlook folder or meeting detail was reviewed. When the user requests all mail and meetings, perform a separate read-only live Outlook reconciliation and state its exact boundary.

### Mail

1. Scan every mail item in the primary mailbox Inbox tree, including rule-created subfolders, plus Sent Items. Use the last successful run with a seven-day overlap so late synchronization and moved messages are not missed.
2. Exclude Drafts, Deleted Items, Junk Email, Outbox, RSS, synchronization folders, and metadata/search folders from action discovery. Report these exclusions; do not claim the entire mailbox was scanned.
3. Report source counts by folder, the total unique messages reviewed, the relevant-message count, and the time boundary. Deduplicate by immutable message ID before analysis.
4. Collapse thread history and classify each relevant current message as `action`, `decision`, `evidence`, `informational`, or `no action`. A keyword match alone is not an action.
5. For relevant actions, inspect attachment names and links read-only and identify what must be brought to a meeting. Do not download or persist attachments unless required and approved.
6. Treat Sent Items as evidence that a request was made, not that it was accepted or completed. Treat Drafts only as outputs to validate, never as incoming evidence.

Shared mailboxes, online archive mailboxes, secondary accounts, and non-default stores are outside the default boundary. Include them only when the user requests them or they are an approved project source, and report whether each was available.

### Calendar

1. Scan the primary default calendar from the start of today through the end of the current workweek, plus the next business-day look-ahead. Expand recurring instances.
2. Capture every event's current subject, times, organizer, relevant attendees, location, body/agenda, response state, free/busy state, and cancellation state. Do not treat canceled or declined events as commitments.
3. Detect every overlap after excluding canceled events. Distinguish meetings from personal focus blocks, lunch, all-day observances, and free events.
4. For each relevant meeting, produce: objective, topics to discuss, evidence to bring, information to provide, decision or ask required, and the concrete leave-with outcome.
5. Report the calendar path, event count, canceled/declined/tentative/not-responded counts, overlap count, and any secondary calendars not reviewed.

The scheduled snapshot must not depend on manual meeting categorization. A non-private event may be collected as `relevant` when it has the `IconDB Control` category or when its subject/body preview contains an approved narrow IconDB term. `Enovia`, attendee identity, or organizer identity alone is not sufficient because each can match unrelated work. Private, confidential, and unmatched events remain `busyOnly`.

Do not overwrite the privacy-minimized snapshot with live Outlook content or persist unrelated subjects, bodies, recipients, or attendee lists in repository files.

## Daily Action Register

Build one in-memory action register after mail, calendar, CPS, PDCA, Jira, and existing To Do reconciliation. Generate the plan draft and Microsoft To Do tasks from this same register so they cannot drift.

Each action must have an outcome-based title, source, accountable owner or decision-maker, due date, dependency, expected evidence, completion condition, and disposition: `today`, `this week`, `waiting`, `informational`, or `blocked`. Merge duplicate asks from the same thread or meeting. Do not create a task for information-only mail, canceled meetings, attendance alone, or an action owned entirely by someone else unless the user must follow up.

## Reconciliation Rules

- Dates determine lateness, not completion. Mark work complete only from sufficient completion evidence.
- Preserve historical `Late` rows for audit and maintain one current recovery path per late baseline.
- Make dependencies explicit in `Project schedule`. If AAC testing requires five BU Rule Manager updates, AAC must depend on all five formulas, not merely mention them in a view or email.
- A production task after a gate must reference that gate explicitly even if its calculated date is already later.
- Validation/UAT must start after both its production/input task and its readiness or test-scenario prerequisite.
- Separate decision dates from execution dates. The 16 September restart decision does not execute Rule Manager changes.
- Keep technical ownership internal in broad program communication. External implementation parties may remain CPS dependencies without being Outlook recipients.
- Preserve neutral wording. Distinguish a stakeholder realignment from abandonment, delay, or lack of engagement.

## Update Order

Apply one dependency layer at a time:

1. shared environment, validation, restart-authority, and handoff gates;
2. BU production and acceptance paths;
3. one Rule Manager task per BU using approved production IconDB names/IDs;
4. AAC E2E after all required BU Rule Manager tasks;
5. generated business and role views; and
6. the SharePoint PDCA summary, actions, decisions, risks, evidence log, and next meeting preparation.

For each layer:

1. run Preview or an equivalent read-only inspection;
2. confirm exact task identities, formulas, owners, dates, and expected row count;
3. apply the smallest approved change;
4. reopen the SharePoint file read-only; and
5. validate before continuing to the next layer.

Do not combine unrelated workbook mutations into one opaque apply operation.

## CPS Validation

At minimum, verify:

- the workbook reopened read-only after save;
- exact changed task text, owners, start/end dates, and formulas;
- every affected successor starts after all controlling predecessors;
- AAC E2E follows every required BU Rule Manager task;
- Late/Recovery parity is unchanged unless an explicitly approved structural change explains it;
- business views link to the expected master task identities;
- no visible `Late` baseline appears in business views;
- Start-page links, chart data, and view navigation work; and
- no broken references or unexpected sheet changes were introduced.

Excel coauthoring can partially autosave before a COM exception. After any Excel COM failure, reopen SharePoint read-only and inspect actual state before retrying. Never assume the failed call left the workbook unchanged. When the failure occurs during formula assignment, render and inspect the exact generated formula string before retrying; a malformed empty-string branch such as `=IF(F222="Done",100%,")` can surface only as generic `0x800A03EC` after earlier cell edits have already coauthored. Make retry logic accept the verified partial state, correct the formula to `=IF(F222="Done",100%,"")`, preview again, and then apply.

## PDCA Update

Update the SharePoint PDCA directly after CPS validation. Keep it concise and operational:

- weekly outcome;
- nearest action, owner, due date, and dependency for each active OU;
- plan-versus-actual variance;
- decisions required and accountable decision owner;
- risks and dependencies;
- dated evidence of completed actions;
- meeting agenda and parking lot; and
- a run-history entry recording coverage, changes, contradictions, drafts created, and validation result.

The PDCA summarizes the verified CPS; it must not become a competing schedule. Link to the SharePoint CPS for detailed dates and dependencies.

## Outlook Drafts

Creating drafts is a standard morning-run output. Drafts may include:

- reminders for actions due or overdue;
- requests for missing owners, decisions, dates, or evidence;
- follow-ups on unresolved dependencies;
- concise BU or program updates; and
- meeting pre-reads or post-meeting action summaries.

Rules:

1. Create or update messages only in Outlook Drafts. Never call `Send()`.
2. Preserve the approved subject/thread choice and recipient scope. Use the internal program distribution for internal program updates; do not add external BVE or delivery contacts unless the user explicitly requests them.
3. Keep each ask explicit: action, accountable internal owner, due date, dependency, and requested evidence.
4. Use CPS-calculated dates only after read-only workbook validation.
5. For formatted mail, edit controlled HTML blocks or rebuild the standalone HTML body. Do not use Word character offsets against Outlook tables or lists; hidden formatting characters make those offsets unsafe.
6. Save, reopen, and verify subject, recipient count, CC/BCC, required phrases, hyperlinks, HTML format, parent Drafts folder, `Sent=False`, and `Submitted=False`.
7. Record the draft subject and purpose in the SharePoint PDCA. Do not record raw private mail content.

For the daily personal pre-read, use the deterministic subject `IconDB morning pre-read and weekly plan - <date>`, address it only to the user, and update the existing same-day draft instead of creating another. Include:

- exact evidence coverage and gaps;
- today's actions in time and dependency order;
- the remaining workweek and next-business-day look-ahead;
- every meeting conflict and response/cancellation issue;
- meeting-specific discuss, bring, inform, decide, and leave-with points;
- mail triage split into action, decision, evidence, and informational items;
- To Do items created, updated, carried over, and completed since the prior run; and
- a mandatory `Developer / Jira versus CPS` section with each key, mismatch/blocker, developer question, requested evidence, impact, and due date; and
- blocked operating-record updates such as read-only SharePoint.

Draft creation does not imply approval to send. The user reviews and sends each message.

## Microsoft To Do Tasks

Create live tasks through the default Outlook mailbox Tasks folder so they synchronize to Microsoft To Do. Use these defaults unless the user explicitly changes them:

1. Create one task per concrete morning-run action in the `Tasks` list, categorized `IconDB Morning Run`.
2. Prefix the subject with `[IconDB]` and keep it outcome-based and independently completable.
3. Set the due date to the verified action date and a 09:00 local reminder. For overdue actions, use today's date and identify the original due date in the notes.
4. Put the source, expected evidence, owner or decision-maker, dependency, and completion condition in the task notes. Do not copy unnecessary private mail content.
5. Before creating a task, check for an existing open task with the same normalized subject or source/action identity regardless of due date. Update its date, reminder, and notes when evidence changed; do not create a new task merely because a due date moved.
6. Reopen every created or updated task and verify its folder, subject, due date, reminder, category, notes, and incomplete state.
7. Never mark a task complete from inferred status, meeting attendance, a sent request, or a date passing. The user checks it off in Microsoft To Do after confirming the evidence.
8. Carry overdue open tasks into today's action register without silently changing the original due date in their notes. Report newly completed tasks separately and reconcile them with formal evidence before proposing CPS or PDCA completion.
9. Create or update personal developer-follow-up tasks produced by the Jira/CPS comparison when the user must ask, decide, review, provide evidence, or follow up. Do not duplicate work owned entirely by a developer as a personal task.

Reconcile the count and titles of `today` actions in the plan draft against the created, updated, or carried-over To Do tasks. Record those counts and purposes in the SharePoint PDCA run history when the PDCA is writable. A task is a personal execution aid; it does not replace the CPS schedule or authorize a status change.

## Lessons From 13 August 2026

These controls are mandatory in future runs:

- Start from the controlling task and dependency formula, not a view, row number, or coincidentally later date.
- Use task-identity lookups because inserted rows invalidate fixed row maps.
- Preview, apply, and read-only reopen are separate gates. Never skip the reopen.
- Recalculate downstream Rule Manager and AAC dates after changing BU production or acceptance paths, then regenerate views.
- Validate chronological semantics, not only formula syntax. The 13 August review caught UAT tasks that were formula-valid but started before production completed.
- Treat SharePoint coauthoring failures as potentially partially saved.
- Build business views from the master in one established generator; do not hand-edit each view.
- Keep Outlook audience and body validation as explicit invariants. A draft in Drafts with the expected subject is insufficient by itself.
- Rebuild controlled HTML when a formatted draft is damaged. Word-range replacement against rendered body offsets can corrupt table and list text.
- Keep the CPS and PDCA in SharePoint only. Local copies create reconciliation work and invite stale dates into later runs.

## Lessons From 25 August 2026

- The scheduled snapshot returned a complete approved search result, but it did not cover an Inbox rule subfolder. For an "all mail" request, audit the full Inbox tree and Sent Items and report folder-level counts and exclusions.
- The privacy-safe snapshot exposed no categorized IconDB meetings even though the live primary calendar contained relevant meetings. Use the snapshot as a privacy baseline and the authorized live read-only pass for current agendas, recurrence instances, response states, cancellations, and conflicts.
- Never report a raw keyword match as relevant without contextual classification. Two omitted `raporty` messages were Smart PDF evidence but created no new action for the user.
- Generate the personal pre-read and To Do tasks from one deduplicated action register. Meeting preparation and mail asks must not produce competing or repeated tasks.
- Use deterministic same-day draft subjects and stable task identity so reruns update existing outputs instead of multiplying them.
- Canonical snapshot validation and Markdown-safe derivative checks are different controls. Validate the canonical source with `Test-IconDBMorningSnapshot.ps1`; validate the derivative for preserved counts, hashed IDs, removed links, and no `busyOnly` detail leakage.
- A read-only SharePoint workbook blocks that operating-record update but does not block personal planning outputs. Report the morning run as `action-ready / control-incomplete`, leave SharePoint unchanged, and retry only after write access is available.
- Jira unavailability fails the morning-run success gate. Preserve other verified evidence, but do not finalize a current developer agenda or claim a successful run. Do not substitute a downloaded export, email digest, or stale status.
- Outlook may normalize HTML list and table markup after save. Replace a uniquely bounded semantic block, save, reopen, and validate the rendered plain text instead of relying on the original HTML fragment.
- To preserve an existing e-mail thread and its inline evidence, create the draft with Outlook `ReplyAll()` from the authoritative source item and prepend the new controlled block. Do not reconstruct the quoted thread or slice it at guessed HTML reply boundaries.
- Before and after any draft rewrite, record attachment names/counts and validate source sender/date, quoted evidence phrases, To/CC/BCC, Drafts parent, `Sent=False`, and `Submitted=False`. A matching subject and attachment count alone are insufficient.
- Resolve recipients through the Outlook address book and read back the resolved display name/address. Do not infer an address from a surname or carry an unrelated participant from the source thread into a new action request.
- Jira assignee lookups must use the live Jira display identity. On 25 August the developer identity resolved as `Stephen Ferda`; a query for `Steve Ferda` returned no issues.
- Explicit user corrections refine the developer discussion register: separate observed functional outcome from unfamiliar technical acceptance language, direct closure to the accountable Jira owner, ask for environment-specific test evidence, and protect an active SIT scope from uncoordinated QA testing.
- Manual `IconDB Control` meeting categories are optional, not an operating prerequisite. The approved collector design uses category or narrow subject/body matching while preserving private/confidential and unmatched events as `busyOnly`.

## Run Sequence

Use this order to minimize repeated reads and divergent outputs:

1. validate/promote the canonical snapshot and validate the Markdown-safe derivative with the correct checks;
2. run the Live Jira Gate; stop the success path if complete live retrieval is unavailable;
3. inspect existing To Do state and establish the last successful run boundary;
4. perform one live Outlook mail-folder pass and one expanded calendar pass, producing coverage counts and classifications;
5. read SharePoint CPS/PDCA and reconcile them with the live Jira inventory;
6. build and deduplicate the daily action and developer discussion registers;
7. preview and apply approved CPS/PDCA changes, then reopen read-only and validate;
8. create or update the single same-day personal plan draft and the matching To Do tasks;
9. reopen and validate every draft and task, then reconcile their counts to the action register; and
10. report one of: `complete`, `action-ready / control-incomplete`, or `failed`, with exact gaps and unchanged authoritative records.

## Completion Checklist

A morning run is complete only when:

- evidence coverage and any gaps are stated;
- Inbox subfolders, Sent Items, recurrence expansion, exclusions, response states, cancellations, and conflicts are accounted for when all Outlook content was requested;
- the complete live Jira inventory and every referenced CPM key were retrieved with paging reconciled;
- Jira/CPS contradictions are reconciled or listed in the developer discussion register;
- SharePoint CPS changes pass read-only validation;
- SharePoint PDCA reflects the verified CPS and current actions;
- the single same-day plan draft covers today, the remaining week, next-business-day look-ahead, meeting preparation, mail triage, conflicts, and source gaps;
- the draft contains a current `Developer / Jira versus CPS` section and its user-owned follow-ups reconcile to To Do;
- requested reminders/follow-ups exist as validated, unsent Outlook drafts;
- concrete daily actions exist as validated, incomplete Microsoft To Do tasks without duplicates;
- the plan's today-action count reconciles to created, updated, or carried-over To Do items;
- no local CPS/PDCA copy was updated;
- no destructive system action or mail send occurred; and
- the user receives a concise summary of changes, open decisions, draft subjects, and validation results.
