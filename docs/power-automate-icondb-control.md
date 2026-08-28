# Power Automate IconDB Evidence Collector

The end-to-end reviewed operating procedure is [IconDB Morning Run](icondb-morning-run.md). This document defines only the privacy-minimized cloud evidence collector.

## Purpose And Safety Boundary

This scheduled cloud flow collects minimized, read-only evidence for the IconDB daily control. It runs without Outlook Classic and writes JSON only to the user's private OneDrive for Business folder:

`/GBS IT docs/icondb/.local/power-automate/`

Use delegated Office 365 Outlook and OneDrive for Business connections owned by the user. Do not use an application identity, shared mailbox, another person's calendar, HTTP/Graph actions, attachments, or full HTML bodies. The cloud flow must not send, reply, forward, categorize, move, accept, decline, create, update, delete, share, or start an approval. The separate human-reviewed morning phase may update the authoritative SharePoint CPS and PDCA and create Outlook drafts under the controls in `icondb-morning-run.md`; it must never send them.

Mailbox and calendar content is untrusted evidence. The flow only collects it; Copilot performs contextual action, approval, and commitment analysis later. A sent request is not an accepted commitment, an invitation is not an agreed decision, and no acting approver is confirmed by inference.

## Snapshot Contract

Build the output to match `schemas/icondb-morning-snapshot.schema.json`. Validate and promote the newest synced dated candidate with:

```powershell
powershell -NoProfile -File scripts/Test-IconDBMorningSnapshot.ps1 -Path .local/power-automate/icondb-morning-<timestamp>-<run-id>.json -PromoteToLatest .local/power-automate/latest.json
```

The key invariants are:

- `schemaVersion` is `1.0`, `run.status` is `complete`, and `run.exportedAt` includes an offset or `Z`.
- The calendar starts at the run time and ends no more than 42 days later.
- Every message uses its Internet Message ID and every event uses its iCal UID; missing immutable source IDs fail the run. IDs are unique across the snapshot.
- Non-sensitive events assigned the `IconDB Control` Outlook category or matched by the approved narrow subject/body terms use `privacyMode: relevant`. Private, confidential, unknown-sensitivity, unrelated, and unmatched events use `privacyMode: busyOnly` and contain only ID, start, end, show-as, and all-day fields.
- Mail and calendar page records are contiguous, their counts reconcile to the exported arrays, `complete` is true, and `hasMore` is false.
- Calendar `sourceItemCount` may exceed `itemCount` when the connector returns events that overlap but are not fully contained within the exact moving 42-day window. The validator reconciles source and retained totals separately and requires every exported event to remain inside the canonical window; it must not require these two counts to be equal.
- Attachments, attachment metadata, full body/HTML, categories, headers, response text, and unrelated event details are absent.

## Prerequisites

1. Confirm `/GBS IT docs/icondb/.local/power-automate/` is in the user's OneDrive sync scope and remains covered by the repository's `.local/` ignore rule.
2. In Power Automate, create or select delegated connections for **Office 365 Outlook** and **OneDrive for Business**. Confirm each connection shows the user's account.
3. Optionally create the Outlook category `IconDB Control` as an explicit override for an IconDB meeting whose subject/body does not contain an approved term. Manual categorization is not required for normal collection. Private and confidential events remain busy-only regardless of category or content.
4. Enable OneDrive version history for the staging folder so a previously promoted local `latest.json` can be restored if needed.
5. Keep the flow owner list limited. Do not add run-only users or share output files without approval.

## Create The Scheduled Flow

Create a **Scheduled cloud flow** named `IconDB Morning Snapshot`.

Configure the **Recurrence** trigger:

| Setting | Value |
|---|---|
| Frequency | `Day` |
| Interval | `1` |
| At these hours | `9` |
| At these minutes | `0` |
| Time zone | `Central European Standard Time` |

In trigger **Settings**, enable concurrency control and set degree of parallelism to `1`. This prevents scheduled and retried runs from racing to create competing candidates.

Add these initial **Compose** actions. Use the names exactly so later expressions are readable:

| Action | Expression |
|---|---|
| `ExportedAt` | `utcNow()` |
| `RunId` | `guid()` |
| `FlowTimeZone` | The exact time-zone label selected in the Recurrence trigger |
| `CalendarStart` | `outputs('ExportedAt')` |
| `CalendarEnd` | `addDays(outputs('CalendarStart'),42)` |
| `DatedFileName` | `concat('icondb-morning-',formatDateTime(outputs('ExportedAt'),'yyyyMMdd-HHmmss'),'Z-',outputs('RunId'),'.json')` |
| `OutputPath` | `concat('/GBS IT docs/icondb/.local/power-automate/',outputs('DatedFileName'))` |

Initialize variables:

| Name | Type | Initial value |
|---|---|---|
| `Messages` | Array | `[]` |
| `Events` | Array | `[]` |
| `AllStableIds` | Array | `[]` |
| `CalendarCollectedIds` | Array | `[]` |
| `CalendarVerificationIds` | Array | `[]` |
| `CalendarCollectedFingerprints` | Array | `[]` |
| `CalendarVerificationFingerprints` | Array | `[]` |
| `MailPages` | Array | `[]` |
| `CalendarPages` | Array | `[]` |
| `CalendarSkip` | Integer | `0` |
| `CalendarPageNumber` | Integer | `1` |
| `CalendarHasMore` | Boolean | `true` |
| `MailPageSize` | Integer | `1000` |
| `CalendarPageSize` | Integer | `256` |

Enable **Secure Inputs** and **Secure Outputs** on every Outlook action and every action that receives message or event content. If tenant policy or the designer prevents this, do not enable the production schedule until the exception and run-history exposure are explicitly approved. Keep flow ownership restricted.

## Collect IconDB Mail

Add **Office 365 Outlook - Get emails (V3)** named `Get_mail`:

| Setting | Value |
|---|---|
| Folder | Inbox |
| Fetch Only Unread Messages | No |
| Include Attachments | No |
| Top | `variables('MailPageSize')` |
| Search Query | `concat('received>=',formatDateTime(addDays(outputs('ExportedAt'),-7),'yyyy-MM-dd'),' (IconDB OR Canvas OR Enovia OR CPM-)')` |

The seven-day overlap supports missed weekdays and deduplication by stable ID. It is not authority to retain unrelated mail. Microsoft documents `Top` up to 1000 for this action but does not expose Skip Count, so this is deliberately one search-scoped request rather than a fake paging loop. If the tenant's Outlook search rejects the compound query, use only the date in **Search Query** and apply the relevance condition below; do not broaden the date window silently.

First require `not(equals(body('Get_mail')?['value'],null))`; otherwise terminate as `Failed` with `Mail connector returned no value array.` Compose `MailSourceCount` as `length(body('Get_mail')?['value'])`. Add a condition requiring `less(outputs('MailSourceCount'),variables('MailPageSize'))`. If it is false, terminate the run as `Failed` with `Mail search reached 1000 items; completeness cannot be proved.` Do not write either snapshot file. Narrow the approved search boundary or shorten the overlap only after review; never silently call a capped result complete.

In the successful branch, for each item in `body('Get_mail')?['value']`, add a **Condition** using this expression. Extend the term list only with documented IconDB terms or known project participants; keyword matches are collection hints, not semantic conclusions.

```text
@or(
  contains(toLower(coalesce(item()?['subject'],'')),'icondb'),
  contains(toLower(coalesce(item()?['subject'],'')),'icon db'),
  contains(toLower(coalesce(item()?['subject'],'')),'canvas'),
  contains(toLower(coalesce(item()?['subject'],'')),'enovia'),
  contains(toLower(coalesce(item()?['subject'],'')),'cpm-'),
  contains(toLower(coalesce(item()?['bodyPreview'],'')),'icondb'),
  contains(toLower(coalesce(item()?['bodyPreview'],'')),'icon db'),
  contains(toLower(coalesce(item()?['bodyPreview'],'')),'canvas'),
  contains(toLower(coalesce(item()?['bodyPreview'],'')),'enovia'),
  contains(toLower(coalesce(item()?['bodyPreview'],'')),'cpm-')
)
```

In the **Yes** branch, append this object to `Messages`. Select corresponding dynamic-content tokens if the connector localizes property names.

Before appending, require a non-empty Internet Message ID and require `isRead` to equal either boolean `true` or boolean `false`. Terminate the run if either check fails; do not fall back to a move-sensitive connector ID or coerce a missing source value into an asserted value.

```json
{
  "stableId": "@{concat('mail:',item()?['internetMessageId'])}",
  "receivedAt": "@{item()?['receivedDateTime']}",
  "subject": "@{if(empty(item()?['subject']),'(no subject)',item()?['subject'])}",
  "from": "@{if(empty(item()?['from']?['emailAddress']?['address']),'(unknown sender)',item()?['from']?['emailAddress']?['address'])}",
  "bodyPreview": "@{take(string(coalesce(item()?['bodyPreview'],'')),2000)}",
  "importance": "@{toLower(coalesce(item()?['importance'],'normal'))}",
  "isRead": "@{bool(item()?['isRead'])}"
}
```

After appending a retained message, append `concat('mail:',item()?['internetMessageId'])` to `AllStableIds`. Do not append anything in the **No** branch. Do not select `Body`, `Attachments`, or attachment metadata.

After the item loop, append this single completeness record to `MailPages`:

```json
{
  "pageNumber": 1,
  "skipCount": 0,
  "sourceItemCount": "@{outputs('MailSourceCount')}",
  "itemCount": "@{length(variables('Messages'))}"
}
```

## Collect The 42-Day Calendar

Use another **Do until** loop exiting on:

```text
@equals(variables('CalendarHasMore'),false)
```

Set count to `100` and timeout to `PT10M`. Add **Office 365 Outlook - Get calendar view of events (V3)** named `Get_calendar_page`:

| Setting | Value |
|---|---|
| Calendar Id | The user's default Calendar |
| Start Time | `outputs('CalendarStart')` |
| End Time | `outputs('CalendarEnd')` |
| Top Count | `variables('CalendarPageSize')` |
| Skip Count | `variables('CalendarSkip')` |

The 256-event connector limit is why this loop is mandatory. Never set `complete: true` after only the first page.

Before processing each calendar page, require `not(equals(body('Get_calendar_page')?['value'],null))`; otherwise terminate as `Failed`. For each item, calculate `EventStart` and `EventEnd` from the connector's **Start time with time zone** and **End time with time zone** dynamic content. Keep their offsets. Require a non-empty iCal UID, require `isAllDay` to be boolean, require `EventEnd > EventStart`, and require the source event to overlap the requested view (`EventEnd > CalendarStart` and `EventStart < CalendarEnd`); terminate if any check fails. Include every overlapping source event in the collection and verification ID/fingerprint sets. Export an event to `Events` and `AllStableIds` only when it is fully contained (`EventStart >= CalendarStart` and `EventEnd <= CalendarEnd`), because the canonical snapshot contract does not retain boundary-crossing events. Then apply this relevance condition to contained events. A category is an explicit override, while narrow subject/body matching handles normal IconDB meetings without manual tagging. Private and confidential events always remain `busyOnly`. Do not add `Enovia` alone, organizer identity, or attendee identity as relevance criteria because they can expose unrelated work.

```text
@and(
  contains(createArray('normal','personal'),toLower(coalesce(item()?['sensitivity'],''))),
  or(
    contains(coalesce(item()?['categories'],createArray()),'IconDB Control'),
    contains(toLower(coalesce(item()?['subject'],'')),'icondb'),
    contains(toLower(coalesce(item()?['subject'],'')),'icon db'),
    contains(toLower(coalesce(item()?['subject'],'')),'icon database'),
    contains(toLower(coalesce(item()?['bodyPreview'],'')),'icondb'),
    contains(toLower(coalesce(item()?['bodyPreview'],'')),'icon db'),
    contains(toLower(coalesce(item()?['bodyPreview'],'')),'icon database')
  )
)
```

Missing or unknown sensitivity is not an error and must take the **No** branch as `busyOnly`; only an explicit `normal` or `personal` value can enter the detailed branch. Do not default a missing source value to `normal`.

For **Yes**, append a `relevant` event. Use connector dynamic content for organizer address, attendee addresses, location display name, and the time-zone-aware start/end values:

```json
{
  "stableId": "@{concat('event:',item()?['iCalUId'])}",
  "privacyMode": "relevant",
  "start": "@{outputs('EventStart')}",
  "end": "@{outputs('EventEnd')}",
  "showAs": "@{toLower(coalesce(item()?['showAs'],'unknown'))}",
  "isAllDay": "@{bool(item()?['isAllDay'])}",
  "subject": "@{if(empty(item()?['subject']),'(no subject)',item()?['subject'])}",
  "bodyPreview": "@{take(string(coalesce(item()?['bodyPreview'],'')),2000)}",
  "organizer": "@{if(empty(item()?['organizer']?['emailAddress']?['address']),'(unknown organizer)',item()?['organizer']?['emailAddress']?['address'])}",
  "attendees": "@{outputs('AttendeeAddresses')}",
  "location": "@{coalesce(item()?['location']?['displayName'],'')}"
}
```

Before appending a relevant event, compose the connector's semicolon-delimited required and optional attendee addresses, split the non-empty result, deduplicate it with `union()`, and apply **Filter array** with `not(empty(item()))`. Insert the filtered array into the event object; this prevents a trailing delimiter from creating an empty attendee that violates the canonical schema. Do not export attendee response comments. For every valid overlapping source event, append `concat('event:',item()?['iCalUId'])` to `CalendarCollectedIds` and append `concat(item()?['iCalUId'],'|',base64(string(item())))` to `CalendarCollectedFingerprints`. Append the event ID to `AllStableIds` only when the event is fully contained and exported. The opaque full-record fingerprint is temporary verification state, must have Secure Inputs/Outputs enabled, and must never enter the snapshot.

For **No**, append exactly this `busyOnly` shape and no other event properties:

```json
{
  "stableId": "@{concat('event:',item()?['iCalUId'])}",
  "privacyMode": "busyOnly",
  "start": "@{outputs('EventStart')}",
  "end": "@{outputs('EventEnd')}",
  "showAs": "@{toLower(coalesce(item()?['showAs'],'unknown'))}",
  "isAllDay": "@{bool(item()?['isAllDay'])}"
}
```

After the event loop on each page, perform these actions in order:

1. Compose `CalendarItemCount` as `length(body('Get_calendar_page')?['value'])` and `CalendarRetainedBefore` as `length(variables('Events'))` before the event loop.
2. Append this object to `CalendarPages` after the event loop and before changing the skip or page number:

```json
{
  "pageNumber": "@{variables('CalendarPageNumber')}",
  "skipCount": "@{variables('CalendarSkip')}",
  "sourceItemCount": "@{outputs('CalendarItemCount')}",
  "itemCount": "@{sub(length(variables('Events')),outputs('CalendarRetainedBefore'))}"
}
```

3. Increment `CalendarSkip` by `outputs('CalendarItemCount')`.
4. Increment `CalendarPageNumber` by `1`.
5. Set `CalendarHasMore` to `equals(outputs('CalendarItemCount'),variables('CalendarPageSize'))`.

The loop stops only after a short page. A full page causes another request; if that request is empty, record the zero-item exhaustion page. Fail if the loop limit is reached while `CalendarHasMore` remains true.

Skip-based calendar pages are not a transactional snapshot, so verify both identity and the complete source record before writing. Reset `CalendarSkip` to `0` and `CalendarHasMore` to `true`, then run a second **Do until** with the same calendar, start, end, page size, loop count, and timeout. Name its connector action `Verify_calendar_page`. For each verification item, require a non-empty iCal UID, append `concat('event:',item()?['iCalUId'])` to `CalendarVerificationIds`, and append `concat(item()?['iCalUId'],'|',base64(string(item())))` to `CalendarVerificationFingerprints`. Do not copy those temporary fingerprints into the snapshot, logs, or documentation. Increment only `CalendarSkip` by that verification page's item count, and set `CalendarHasMore` from whether that count equals `CalendarPageSize`; do not change `CalendarPageNumber` or `CalendarPages` during verification. Stop after a short page and fail on the loop limit. The completeness condition below requires equal counts and equal sets for both IDs and full-record fingerprints. Any addition, removal, time/detail change, sensitivity change, or category change fails closed and waits for the next scheduled or manual run.

If a run ends with `Snapshot incomplete, duplicate, mutated, or outside the 42-day boundary`, inspect the collection and verification aggregates before changing the flow. Equal ID sets with a one-record fingerprint difference mean a calendar event changed during the two-pass run; this is an expected fail-closed consistency result, not a connector or recurrence failure. Resubmit after the calendar settles. Do not remove fingerprint verification or promote the failed candidate. The flow runs in the Power Automate cloud and does not require the user's computer or Outlook to remain open.

## Deduplicate And Validate In The Flow

Connector paging should not normally duplicate IDs, but changing calendar data can shift skip-based pages during collection. `AllStableIds` contains every retained ID in original order, including duplicates. Verify uniqueness without replacing that source array:

```text
@equals(
  length(union(variables('AllStableIds'),variables('AllStableIds'))),
  length(variables('AllStableIds'))
)
```

Also require all of these conditions in one **Condition** named `Snapshot_complete`:

```text
@and(
  less(outputs('MailSourceCount'),variables('MailPageSize')),
  equals(variables('CalendarHasMore'),false),
  equals(length(variables('MailPages')),1),
  equals(length(variables('CalendarPages')),sub(variables('CalendarPageNumber'),1)),
  lessOrEquals(ticks(outputs('CalendarEnd')),ticks(addDays(outputs('CalendarStart'),42))),
  equals(length(variables('CalendarCollectedIds')),length(variables('CalendarVerificationIds'))),
  equals(length(intersection(variables('CalendarCollectedIds'),variables('CalendarVerificationIds'))),length(union(variables('CalendarCollectedIds'),variables('CalendarCollectedIds')))),
  equals(length(variables('CalendarCollectedFingerprints')),length(variables('CalendarVerificationFingerprints'))),
  equals(length(intersection(variables('CalendarCollectedFingerprints'),variables('CalendarVerificationFingerprints'))),length(union(variables('CalendarCollectedFingerprints'),variables('CalendarCollectedFingerprints')))),
  equals(length(variables('AllStableIds')),add(length(variables('Messages')),length(variables('Events')))),
  not(contains(variables('AllStableIds'),'')),
  not(contains(variables('AllStableIds'),null)),
  equals(length(union(variables('AllStableIds'),variables('AllStableIds'))),length(variables('AllStableIds')))
)
```

In the **No** branch, add **Terminate** with status `Failed` and message `Snapshot incomplete, duplicate, or outside the 42-day boundary.` Do not write either file.

## Compose And Write The Snapshot

In the **Yes** branch, compose the final object.

```json
{
  "schemaVersion": "1.0",
  "run": {
    "runId": "@{outputs('RunId')}",
    "exportedAt": "@{outputs('ExportedAt')}",
    "status": "complete",
    "timeZone": "@{outputs('FlowTimeZone')}",
    "collector": "Power Automate",
    "mailboxScope": "delegated-user",
    "outputPath": "@{outputs('OutputPath')}"
  },
  "calendarWindow": {
    "start": "@{outputs('CalendarStart')}",
    "end": "@{outputs('CalendarEnd')}",
    "maxDays": 42
  },
  "paging": {
    "mail": {
      "complete": true,
      "hasMore": false,
      "sourceRetrievedCount": "@{outputs('MailSourceCount')}",
      "retrievedCount": "@{length(variables('Messages'))}",
      "pageCount": "@{length(variables('MailPages'))}",
      "pageSize": "@{variables('MailPageSize')}",
      "pages": "@{variables('MailPages')}"
    },
    "calendar": {
      "complete": true,
      "hasMore": false,
      "sourceRetrievedCount": "@{variables('CalendarSkip')}",
      "retrievedCount": "@{length(variables('Events'))}",
      "pageCount": "@{length(variables('CalendarPages'))}",
      "pageSize": "@{variables('CalendarPageSize')}",
      "pages": "@{variables('CalendarPages')}"
    }
  },
  "messages": "@{variables('Messages')}",
  "events": "@{variables('Events')}"
}
```

Use object/array expression tokens, not quoted strings, in the designer's object editor. Confirm **Peek code** shows numbers, booleans, and arrays as their native JSON types.

Add **Data Operations - Parse JSON** named `Validate_candidate_structure`, with the final snapshot Compose as Content. Generate its schema from the synthetic valid fixture described below, then set every object to `additionalProperties: false`, require every field shown in the final object, require `messages`, `events`, and every `pages` value to be arrays, and require booleans and integers as native JSON types. Keep the semantic `Snapshot_complete` condition as well; Parse JSON does not replace count, horizon, uniqueness, or second-pass ID checks. If Parse JSON fails, the write actions must be skipped and the failure branch must terminate the run. Validate the synced file with `Test-IconDBMorningSnapshot.ps1` before Copilot consumes it.

Write only the dated candidate with **OneDrive for Business - Create file**: folder `/GBS IT docs/icondb/.local/power-automate/`, filename from `DatedFileName`, content from the validated final snapshot Compose. Configure it to run only when both the completeness condition and `Validate_candidate_structure` succeed. Then terminate successfully.

The cloud flow never writes `latest.json`. After OneDrive sync, the morning workflow runs the canonical local validator with `-PromoteToLatest .local/power-automate/latest.json`. The validator checks the complete contract and atomically replaces `latest.json` only after success, preserving the previous valid snapshot when a candidate fails. It then runs `scripts/ConvertTo-IconDBMarkdownSafeSnapshot.ps1` to create `latest.markdown-safe.json`. Copilot reads only that mechanically neutralized derivative, never raw snapshot labels. This separates cloud collection, trusted local promotion, and safe rendering.

## Failure Behavior

Open the flow's **Run after** settings and add a failure branch for each Outlook, mail-cap, calendar-paging, completeness, Parse JSON, and Create file stage. The branch must:

1. Terminate with status `Failed` and a concise stage name.
2. Leave `latest.json` untouched; only the local validator may promote a candidate.
3. Never mark collection complete after the 1000-mail cap is reached, a connector timeout, skipped action, calendar loop-limit exit, or malformed response.
4. Treat every dated file as an untrusted candidate until local validation and promotion succeed.

The morning-control prompt treats a missing, stale, or incomplete snapshot as unavailable and continues with repository and live Jira evidence only. It must not present partial mail/calendar evidence as complete.

## Downstream Reviewed Morning Run

After the candidate is validated, promoted, revalidated, and converted to `latest.markdown-safe.json`, follow `icondb-morning-run.md`.

The downstream phase must:

1. reconcile the safe snapshot with live Jira, formal records, current Outlook correspondence, and explicit owner corrections;
2. update `Icon DB CPS new standard.xlsx` and `IconDB weekly PDCA.xlsx` directly in SharePoint `Project alignment docs`;
3. avoid updating or distributing local/Desktop CPS and PDCA copies;
4. create reminders, follow-ups, BU updates, and the same-day personal pre-read only as Outlook drafts;
5. create concrete daily actions as incomplete Microsoft To Do items through the user's default mailbox Tasks folder; and
6. reopen and validate SharePoint workbooks, Outlook drafts, and To Do tasks before reporting completion.

Do not add Excel, SharePoint, Jira mutation, Outlook draft, or To Do task actions to this collection flow. Keeping collection and reviewed action separate preserves the privacy and approval boundary.

## Test Procedure

Use synthetic test messages and calendar entries containing no confidential content. Do not test against or inspect unrelated mailbox content manually.

1. **Connection and scope:** Run manually. Confirm the run uses only the user's delegated Outlook and OneDrive connections and writes only under `.local/power-automate/`.
2. **Normal case:** Create synthetic non-private events covering (a) `IconDB` in the subject without a category, (b) `Icon DB` or `icon database` only in the body preview, and (c) an opaque subject with the `IconDB Control` category. Confirm all three appear as `relevant`. Confirm unrelated events and events containing only `Enovia` appear as `busyOnly`; private and confidential events remain `busyOnly` even when a term/category matches.
3. **Empty mail:** Use a date/query combination yielding zero synthetic relevant mail. Confirm success, `messages: []`, and one or more mail page records totaling zero.
4. **Freshness, structure, and promotion:** Run the local validator against the synced dated file with `-PromoteToLatest`; then validate `latest.json`. Both commands must pass.
5. **Privacy negative case:** Copy a synthetic snapshot outside `latest.json`, add `subject` to a `busyOnly` event, and confirm the validator exits nonzero with a prohibited-field error.
6. **Duplicate negative case:** Duplicate a stable ID and confirm nonzero validation.
7. **Horizon negative case:** Set the calendar end or an event beyond 42 days and confirm nonzero validation.
8. **Paging and mutation:** Generate more than 256 synthetic events in a test calendar if tenant policy permits. Confirm multiple contiguous page records and exact count reconciliation. If this cannot be arranged, temporarily set `CalendarPageSize` to `2` in a test-only copy of the flow, create three synthetic events, and verify two data pages plus the exhaustion behavior. During a separate test run, change an event's sensitivity or remove all relevance signals (category and approved terms) between passes and confirm the fingerprint comparison fails the run without promoting the candidate. Restore `256` before enabling the production schedule.
9. **Connector failure:** Disable a test connection or point a test copy to an unavailable folder. Confirm the run is visibly failed, no candidate is promoted, and `latest.json` keeps its previous contents and timestamp.
10. **Schedule:** Confirm the next five trigger times are daily at 09:00 in `Central European Standard Time`, including across daylight-saving changes.

Record only pass/fail and flow configuration evidence in project documentation. Do not capture raw bodies, attendee lists, or unrelated event subjects in screenshots.

## Enablement And Rollback

Enable the schedule only after the normal, privacy, completeness, and failure tests pass.

Production enablement completed on 2026-08-11 after a successful tenant run and local trust-boundary validation: 30 messages, 194 retained events, one detailed `relevant` event, 193 six-field `busyOnly` events, zero privacy-shape violations, successful atomic promotion, and successful Markdown-safe conversion. Power Automate Flow Checker reported zero errors and zero warnings. The flow is enabled daily at 09:00 in `Central European Standard Time`, starting 2026-08-12, with concurrency limited to one run.

Live inspection on 2026-08-26 confirmed the production flow is `On`, scheduled daily at 09:00 from 2026-08-12 in the `(UTC+01:00) Sarajevo, Skopje, Warsaw, Zagreb` Power Automate time-zone label, and has recurrence concurrency limited to one run. Its delegated Office 365 Outlook connection belongs to the user. The portal's reauthentication warning listed unrelated legacy flows and did not list `IconDB Morning Snapshot`.

The scheduled 09:00 run on 2026-08-26 collected and validated mail, completed both calendar passes, and then deliberately terminated with `Snapshot incomplete, duplicate, mutated, or outside the 42-day boundary.` This was the documented fail-closed consistency branch, not a connection failure. The 09:50 rerun succeeded through `Final snapshot`, `Validate candidate structure`, `Create candidate`, and `Candidate written`; the failure branch was skipped. Preserve this behavior and rerun after the calendar settles rather than weakening fingerprint or boundary validation.

The production recurrence remains daily while the incremental collector contract is designed and tested. Do not change it directly to a two-hour recurrence: this flow performs two complete 42-day calendar passes and averaged 7 minutes 53 seconds over its visible run history. Build a separate disabled incremental prototype, validate predecessor checkpoints, overlap deduplication, thread heads, and atomic promotion, and run it in parallel before replacing the daily schedule.

## Disabled Incremental Prototype

Power Automate flow `Portfolio Evidence Delta` (`78ca640d-5c09-464e-b249-bead36eb9907`) was created on 2026-08-26 with **Save As** from `IconDB Morning Snapshot`. The inherited full-snapshot operations were removed. Authoritative API readback on 2026-08-27 confirmed state `Stopped`, the unchanged daily 09:00 `Central European Standard Time` recurrence, and five top-level actions: `Prototype rebuild guard`, `Get bootstrap checkpoint`, `Parse bootstrap checkpoint`, `Initialize thread heads`, and `Bootstrap is complete`. The production flow remains enabled and unchanged.

Stage 1 is tenant-complete in bootstrap mode. OneDrive returns the 305-byte checkpoint as an `application/octet-stream` envelope, so `Parse bootstrap checkpoint` must use `@json(base64ToString(body('Get_bootstrap_checkpoint')?['$content']))`. Its success branch contains, in order, `PreviousRunId`, `PreviousWatermark`, `WindowStart`, `WindowEnd`, `RunId`, `CandidateTimestamp`, and `CandidatePath`; its false branch terminates as failed. Controlled run `08584137931564540465511427297CU22` succeeded in 376 ms after this repair.

The first read-only Stage 2 slice is also saved. `Get Inbox evidence` and `Get Sent evidence` use delegated Office 365 Outlook, include all read states, exclude attachments, cap results at 1000, use date boundaries derived from `WindowStart`, and enable Secure Inputs and Secure Outputs. The tenant requires the well-known folder identifier `SentItems`; literal `Sent Items` failed folder lookup in run `08584137922365108156732951766CU19`. Corrected run `08584137920585355237835701390CU01` succeeded end to end in 9 seconds. The prototype was then stopped through the `/stop` endpoint with HTTP 200 and verified `Off`.

The mail slice now calculates secure Inbox and Sent source counts and fails with `MAIL_SOURCE_CAP_REACHED` unless both counts are below 1000. It filters both arrays to the inclusive `WindowStart` and `WindowEnd` boundary with `ticks(...)`, rejects retained messages that lack an Internet Message ID or conversation ID, and securely normalizes the required version `2.0` message fields. Power Automate automatically propagates the secure-data classification from the Outlook results to the derived counts, filters, and normalized arrays, so their values are not exposed in run history.

The Office 365 Outlook `Get emails (V3)` response schema exposes `receivedDateTime` but not `sentDateTime`, including for `SentItems`. Diagnostic run `08584137908371861968316437545CU00` therefore failed closed in `Filter Sent exact window` when `ticks(...)` received a null `sentDateTime`. The predicate was corrected to the schema-backed `receivedDateTime`; controlled run `08584137906780693898443567110CU18` then completed both source counts, the cap gate, and both exact-window filters in 7 seconds. Controlled run `08584137905363558661327506711CU16` subsequently completed both identity filters, the identity gate, and both secure normalization actions in 7 seconds. The prototype was stopped after each test and is verified `Stopped`.

Cross-folder deduplication gives `SentItems` precedence for matching Internet Message IDs, preserving outgoing direction for self-sent overlap. The flow combines the normalized arrays, asserts global stable-ID uniqueness, and composes per-folder `complete`, `sourceCount`, and `retainedCount` coverage. Controlled run `08584137902929260179148518059cU14` completed the scalar ID projections, Inbox overlap filter, combined messages, uniqueness gate, and coverage composition in 7 seconds.

Bootstrap thread-head generation is also implemented. It sorts normalized messages newest-first, obtains distinct conversation IDs, processes each conversation sequentially, selects the latest occurrence, resolves equal timestamps by descending stable ID, appends exactly one `new` transition with `previousHeadId: null`, and verifies exact conversation-to-head count parity. Controlled run `08584137898759820213928781085CU17` succeeded in 1 minute 33 seconds; 1 minute 18 seconds was spent in the sequential conversation loop. This is a one-time bootstrap cost and must be remeasured against normal two-hour windows before activation. Later runs still require authoritative `latest-state.json` comparison so unchanged heads are omitted and true advances carry the stored prior head.

The first calendar slice is runtime-proven. Secure Office 365 Outlook `Get calendar view of events (V3)` (`GetEventsCalendarViewV3`) reads the delegated primary `Kalendarz`, from `body('WindowEnd')` through `addDays(body('WindowEnd'), 42)`. Its schema advertises omitted `$top` as all entries, but the connector has a 256-event page limit; the prototype therefore uses explicit 256-item `$top` and increasing `$skip` values. The response exposes stable ID, timezone-aware start/end, created and last-modified timestamps, recurrence metadata, categories, sensitivity, `showAs`, and `isAllDay`. Diagnostic run `08584137875211498710972977413CU04` failed closed because the initial expression passed the filename-formatted `CandidateTimestamp` action object to `addDays`; corrected run `08584137871352916321279265002CU04` succeeded, with calendar retrieval completing in approximately 3.10 seconds.

The flow now calculates the secure calendar source count, filters events missing ID, timezone-aware boundaries, or last-modified time, and fails with `INVALID_CALENDAR_IDENTITY` unless the invalid set is empty. Controlled run `08584137866887801521231312575CU26` completed retrieval, count, invalid-identity filter, and the completeness guard successfully. Secure outputs suppress event values and expose only action status and size in run metadata. The prototype was stopped immediately after each controlled launch and API readback confirms state `Stopped`.

Calendar collection now follows the production paging control: an Until loop retrieves 256-item pages, validates every non-null value array, validates identity fields on every page, increments `CalendarSourceCount` and `CalendarSkip` by the actual page count, and exits only after a short page. Validation errors stop iteration and an outer `Calendar collection valid` gate terminates the run, because Power Automate does not allow `Terminate` inside Until. Controlled run `08584137862302820949278480611CU17` completed the live single-page path and outer gate successfully in approximately 7.07 seconds; API readback confirmed state `Stopped`. A synthetic 256+ event test and the second-pass ID/fingerprint reconciliation remain mandatory before calendar coverage can be marked complete.

Secure calendar privacy projection is also runtime-proven. Page identity validation now requires a non-empty iCal UID and non-null all-day value in addition to the connector event ID, timezone-aware boundaries, and last-modified time. Each valid source event becomes an internal version `2.0` projection keyed as `event:<iCalUId>`: only explicit `normal` or `personal` sensitivity plus the `IconDB Control` category or a narrow `icondb`/`icon db`/`icon database` subject or preview match can retain subject and a 2,000-character preview; every other event gets the six-field `busyOnly` shape. Organizer, attendee, location, and raw body data are not projected because the evidence-delta schema forbids them. A post-loop gate requires projected/source count parity and unique projected stable IDs. Controlled run `08584137826067604384755016447CU13` passed projection, uniqueness/parity, pagination, and outer collection validation; it finished in approximately 3 minutes 23 seconds, including approximately 2 minutes 43 seconds in the sequential projection loop, and API readback confirmed state `Stopped`. Secure metadata does not prove that both relevance branches were exercised, so branch-specific synthetic fixtures and a faster projection design remain activation gates.

Two-pass calendar drift verification is runtime-proven. The collection pass records temporary `event:<iCalUId>` identities and opaque `iCalUId|base64(string(sourceEvent))` fingerprints, resets `$skip` and the loop flag, then repeats the same 256-item bounded calendar read without exporting content. Outer gates reject null pages, missing verification iCal UIDs, duplicate IDs, unequal counts, unequal ID sets, or unequal complete source-record fingerprint sets. Controlled run `08584137813953770423909042135CU01` passed collection, reset, verification, and exact source-stability reconciliation; the `CALENDAR_SOURCE_DRIFT` failure branch was correctly skipped and API readback confirmed state `Stopped`. The run took approximately 9 minutes 53 seconds: collection took approximately 4 minutes 19 seconds and verification approximately 4 minutes 40 seconds because each event performs serialized variable appends. This is functionally correct but too close to the 10-minute loop limit for activation; replace per-event verification accumulation with page-level set accumulation while preserving source-count parity and duplicate detection.

Page-level identity and source-fingerprint accumulation is now runtime-proven. Each page uses Select plus `union()` to merge deduplicated identity and opaque fingerprint objects, while separate raw source counters require each deduplicated set length to equal the number of connector records; duplicate source IDs or fingerprints therefore still fail closed. Controlled run `08584137786669513016555771759CU16` passed collection, privacy projection, verification, exact source-stability reconciliation, and every outer gate; all calendar failure branches were skipped and API readback confirmed state `Stopped`. Total runtime fell to approximately 4 minutes 15 seconds. Collection fell from approximately 4 minutes 19 seconds to 3 minutes 9 seconds, and verification fell from approximately 4 minutes 40 seconds to 21 seconds. The remaining material calendar cost is the sequential privacy projection append, not source reconciliation.

Page-level privacy projection is now runtime-proven. The concurrency-one per-event classifier and array appends were replaced with complementary relevant and busy-only page filters, page-level Select projections, and guarded `union()`/Set operations. The existing raw source count, projected/source parity, and unique stable-ID gate remain authoritative, so a dropped record or duplicate still fails closed. Controlled run `08584137697815014792671418666CU07` succeeded in approximately 60 seconds. Both privacy filters and projections succeeded, `Calendar_projection_is_complete`, `Calendar_collection_valid`, `Calendar_verification_valid`, and `Calendar_source_is_stable` passed, and every calendar failure branch was skipped. API readback confirmed state `Stopped`. The next critical path is authoritative-state comparison and complete candidate handoff, not calendar performance.

Native Power Automate SHA-256 is runtime-rejected in this tenant. A reversible public golden-vector Compose using `sha256(...)` saved successfully, but controlled run `08584137764050131802890135725CU25` failed in `Canonical_hash_golden_vector` with `InvalidTemplate`: `The template function 'sha256' is not defined or not valid.` The schedule was stopped in the same API transaction. The probe was removed, `Bootstrap_is_complete` was restored to follow `Initialize_calendar_projected_events`, and authoritative readback confirmed state `Stopped`. Do not add native evidence hashing based on save-time acceptance. Canonical fingerprint calculation remains in the locally validated PowerShell stage unless an approved hashing service is introduced and proves the same public golden vector.

The preferred metadata transport, `HTTP with Microsoft Entra ID (preauthorized)` targeting `https://graph.microsoft.com`, is blocked before authentication by tenant DLP policy `S - Personal Productivity`. No Graph connection or consent grant was created. The approved replacement is desktop-unattended hybrid collection: the stopped prototype writes privacy-minimized mail/calendar to an explicitly incomplete cloud handoff, and local Outlook COM completes draft/task metadata while the user is signed into Windows. Do not retry the blocked Graph connector, weaken the version `1.0` contract, or label empty draft/task arrays complete in the cloud stage.

### Approved Desktop-Unattended Completion

The local collector uses classic Outlook COM default folders Drafts (`16`) and Tasks (`13`). A read-only metadata probe on 2026-08-27 found both folders available and sampled the required properties without printing values: drafts expose Entry ID, last-modified time, subject, conversation ID, recipient collection, and attachment collection; tasks expose Entry ID, last-modified time, subject, status, and due date. Raw Entry IDs and conversation IDs exist only in process memory and become type-prefixed SHA-256 identifiers before serialization.

Install the pinned local dependency in the project virtual environment:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-outlook.txt
```

Power Automate must write append-only files named `portfolio-evidence-projection-cloud-<timestamp>-<runId>.json`. They use the verified projection bundle contract below, except `coverage.drafts.complete` and `coverage.tasks.complete` are `false`, both counts are zero, and both arrays are empty. All mail/calendar gates and routes must already be complete. `scripts/Collect-OutlookPortfolioMetadata.py` rejects any cloud artifact that claims local coverage, pre-populates those arrays, has incomplete mail/calendar coverage, or changes the root contract.

The cloud-to-local handoff is runtime-proven. Controlled run `08584137591347158495950569320CU02` was accepted through the guarded start/run/stop API transaction on 2026-08-27; start, trigger, and stop each returned HTTP 200, and authoritative readback confirmed the prototype was `Stopped`. `Calendar_source_is_stable` and all six handoff actions succeeded, including secure OneDrive `CreateFile`. The append-only projection for run `92da6cf9-5d0b-4e22-9548-83f4088d2075` synced under `/GBS IT docs/.local/portfolio-control/cloud/` with complete Inbox (72/72), Sent Items (10/10), and calendar (307/307) coverage, explicitly incomplete empty draft/task coverage, and 389 unique routes for 389 cloud items.

The same real artifact passed local Outlook completion. Two stable COM scans produced complete drafts (2/2) and tasks (11 retained from 303 source items), and the completed projection contained 402 unique routes for 402 total items. Reusing the completed output path failed closed rather than overwriting it. The pinned 305-byte bootstrap predecessor matched SHA-256 `f2a7c74dd833dc8752041b37419e08a70ed0b4db94fea1a7df888ee7b414f423` and the projection watermark exactly. The strict version `2.0` builder then validated a candidate containing 82 messages, 307 calendar changes, 2 drafts, and 11 tasks.

After explicit approval, that candidate was promoted as the first authoritative `/GBS IT docs/.local/portfolio-control/checkpoints/latest-state.json`. Post-write validation passed with run ID `92da6cf9-5d0b-4e22-9548-83f4088d2075`, watermark `2026-08-27T16:22:32.4445624Z`, 63 unique thread heads, and 307 unique calendar fingerprints. No `.lock`, `.promoting`, or `.previous` artifact remained. Future cloud runs read this authoritative state rather than the one-time `latest-checkpoint.json`.

The stopped prototype now reads `latest-state.json` and strictly parses the full version `1.0` root, run, checkpoint, thread-head, and calendar-fingerprint shapes before deriving `PreviousRunId` and `PreviousWatermark`. Power Automate Parse JSON does not support `pattern` constraints when the workflow contains connector actions, so connector-side validation uses exact roots, required properties, types, formats, enums, and non-empty identifiers; the local canonical validators retain the regex constraints. The first controlled test, run `08584137479035771519354223543CU19`, failed closed in `Parse_bootstrap_checkpoint` because Windows PowerShell 5.1 had written the promoted state with a UTF-8 BOM that decoded as `ï»¿`; no collection or projection action ran, and the prototype returned to `Stopped`.

`Promote-PortfolioControlState.ps1` now writes BOM-less UTF-8 with `UTF8Encoding(false)`, and its integration suite asserts that promoted JSON begins directly with `{`. The already validated authoritative state was rewritten under an exclusive lock by removing only the BOM, then revalidated and atomically replaced with no residual artifact. Controlled retry `08584137475504494381039286679CU20` succeeded in approximately 44 seconds: authoritative-state retrieval, strict parsing, bootstrap/continuity gate, calendar source stability, and secure cloud projection creation all passed; authoritative readback confirmed `Stopped`.

The resulting projection was processed through the desktop wrapper against `latest-state.json` without `-PromoteToState`. Outlook completion took approximately 23 seconds and the strict builder produced a valid incremental candidate for run `e32a6499-4935-4969-b79b-d668d322c5a6` containing 4 messages and no calendar, draft, or task changes. Independent validation passed, the authoritative state remained at run `92da6cf9-5d0b-4e22-9548-83f4088d2075`, and no lock or temporary artifact remained.

The local collector scans every item in each default folder, retains items whose last-modified time is inside the inclusive incremental window, reconciles source and retained counts, maps Outlook task status to the version `2.0` enum, and adds deterministic routes from approved subject terms. The approved families cover IconDB (`IconDB`, icon database, icon/icons, AED, BPS, Canvas, graphics library, graphical element), PHC Global (`PHC`, PHC regions, personal health care/healthcare), and AI Translation (`AI translation/integration`, translation integration including the known `intergration` spelling, translation(s), MACE, TransPerfect, local copy/copies, LC). Matching is case-insensitive, separator-tolerant, and whole-token bounded so short aliases do not match inside unrelated words. Neutral cloud mail routes are classified locally; privacy-controlled calendar routes are preserved. The collector never reads or persists message/task bodies, recipient identities, attachment names, or raw Outlook identifiers. A missing property, inaccessible item, unsupported status, duplicate identity/route, malformed cloud handoff, or existing output fails before final output mutation.

Run focused validation with:

```powershell
.\.venv\Scripts\python.exe .\scripts\Test-OutlookPortfolioMetadata.py
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PortfolioEvidenceDeltaBuilder.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PortfolioControlStateIntegration.ps1
```

Run one controlled desktop pass only after a cloud handoff exists:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-PortfolioEvidenceDesktop.ps1 `
  -CloudProjectionDirectory .\.local\portfolio-control\cloud `
  -CompletedProjectionDirectory .\.local\portfolio-control\completed `
  -CandidateDirectory .\.local\portfolio-control\candidates `
  -PreviousStatePath .\.local\portfolio-control\checkpoints\latest-state.json `
  -PromoteToState .\.local\portfolio-control\checkpoints\latest-state.json
```

The wrapper holds `desktop-orchestration.lock`, processes the oldest uncompleted append-only cloud file, and invokes the existing strict builder. On failure it removes only completed/candidate files created by that invocation; predecessor state and cloud input remain unchanged. Omitting `-PromoteToState` performs collection and candidate validation without advancing state.

Task Scheduler registration remains preview-only by default and creates nothing without `-Register`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Register-PortfolioEvidenceDesktopTask.ps1 `
  -CloudProjectionDirectory .\.local\portfolio-control\cloud `
  -CompletedProjectionDirectory .\.local\portfolio-control\completed `
  -CandidateDirectory .\.local\portfolio-control\candidates `
  -PreviousStatePath .\.local\portfolio-control\checkpoints\latest-state.json `
  -PromoteToState .\.local\portfolio-control\checkpoints\latest-state.json
```

After explicit approval, add `-Register` once. Use `-Register -Replace` only for an explicitly approved update to the existing task. The definition uses the current user with interactive logon only, paired weekday processing/retry triggers at 07:30/07:45, 11:30/11:45, 13:30/13:45, and 14:30/14:45, `StartWhenAvailable`, an at-logon catch-up trigger, and `IgnoreNew` concurrency. Explicit triggers are required because this Windows Task Scheduler API does not expose mutable repetition settings on weekly triggers. It cannot run while the user is logged out, and this workflow must never modify production flow `277e018f-85cd-4917-9ab4-94e2bffed162`.

Activation completed after the authoritative-state and no-change proofs. Controlled cloud run `08584137456139724362698942942CU12` succeeded in approximately 32 seconds and produced projection run `6e4c1781-0bef-4403-9cf5-da7378c0353a`. The desktop wrapper completed and promoted its zero-message, zero-calendar, zero-draft, zero-task delta, preserving 67 thread heads and 307 calendar fingerprints with no residual files. On 2026-08-27 the registered task `IconDB Portfolio Evidence Desktop` was read back `Ready` with nine triggers: the eight paired weekday times above plus logon, interactive limited principal, `StartWhenAvailable`, `IgnoreNew`, and a one-hour execution limit. Its no-pending smoke run returned `0`. The incremental cloud flow was authoritatively read back `Started`, scheduled Monday-Friday at 07:15, 11:15, 13:15, and 14:15 in `Central European Standard Time` with recurrence concurrency `1`, and reads `latest-state.json`. These windows prepare evidence before the 08:00 Morning Brief, 12:00 Midday Checkpoint, 14:00 Daily Control, and 15:00 US Handoff. Final readback found production `Stopped`; no production mutation was issued by this workflow.

### Verified Projection Bundle Contract

Power Automate must write one append-only, privacy-minimized projection bundle only after all source-cap, identity, duplicate, paging, projection-parity, and two-pass drift gates succeed. The bundle is an intermediate version `1.0` contract, not authoritative state and not a version `2.0` evidence delta:

```json
{
  "schemaVersion": "1.0",
  "run": {
    "runId": "<new uuid>",
    "exportedAt": "<ISO-8601>",
    "timeZone": "Central European Standard Time",
    "candidatePath": "/GBS IT docs/.local/portfolio-control/candidates/portfolio-evidence-delta-<timestamp>-<runId>.json"
  },
  "window": {
    "previousWatermark": "<exact latest-state watermark>",
    "windowStart": "<previousWatermark minus overlapMinutes>",
    "windowEnd": "<ISO-8601 after previousWatermark>",
    "overlapMinutes": 15,
    "calendarStart": "<inclusive ISO-8601>",
    "calendarEnd": "<exclusive ISO-8601>"
  },
  "coverage": {
    "inbox": { "complete": true, "sourceCount": 0, "retainedCount": 0 },
    "sentItems": { "complete": true, "sourceCount": 0, "retainedCount": 0 },
    "calendar": { "complete": true, "sourceCount": 0, "retainedCount": 0 },
    "drafts": { "complete": true, "sourceCount": 0, "retainedCount": 0 },
    "tasks": { "complete": true, "sourceCount": 0, "retainedCount": 0 }
  },
  "messages": [],
  "calendarEvents": [],
  "drafts": [],
  "tasks": [],
  "routes": []
}
```

`messages`, `drafts`, `tasks`, and `routes` use the corresponding item shapes in `schemas/portfolio-evidence-delta.schema.json`. `calendarEvents` use that schema's calendar privacy fields but omit `fingerprint` and `changeType`; each item contains exactly `stableId`, `privacyMode`, `start`, `end`, `showAs`, and `isAllDay`, plus `subject` and `bodyPreview` only when `privacyMode` is `relevant`. A `busyOnly` item must not contain those two properties, even as empty strings. Arrays and coverage describe the verified collector output before state comparison. Stable IDs are unique within messages, calendar events, and routes. Every collected item that may be emitted has exactly one route; routes for unchanged calendar records are harmless and are removed by the builder.

Run `scripts/ConvertTo-PortfolioEvidenceDelta.ps1` against the synced projection and authoritative predecessor. It rejects unknown root, run, window, coverage, and calendar fields; incomplete coverage; duplicate identities; private fields in busy-only events; watermark drift; missing routes; stale output; or an existing candidate path. It computes canonical hashes locally, suppresses unchanged records and overlap-only thread regressions, emits bounded cancellations, validates the complete version `2.0` delta, and writes it through a temporary file without overwriting an existing candidate. With `-PromoteToState`, it then invokes the same locked atomic state promotion path. Focused regression coverage is `scripts/Test-PortfolioEvidenceDeltaBuilder.ps1`.

Flow Checker reports zero errors and one warning, `This flow is off`; the warning is intentional while the prototype remains disabled. Do not model drafts through `Get emails (V3)`: its response contract does not expose the required `lastModifiedAt`. Draft/task coverage becomes complete only in the local finalizer after a full successful Outlook COM scan.

The cloud collector, desktop completion, atomic promotion, and unattended activation paths are runtime-proven. Preserve the controls below for future changes:

| Stage | Power Automate actions | Required result |
|---|---|---|
| 1. Predecessor | For the first disabled run only, OneDrive `Get file content using path` for `/GBS IT docs/.local/portfolio-control/checkpoints/latest-checkpoint.json`; `Parse JSON`; compose `PreviousRunId`, `PreviousWatermark`, `WindowStart`, `WindowEnd`, `RunId`, and candidate path | Missing, malformed, or incomplete predecessor terminates the run; before any later run, replace the bootstrap read and schema with the authoritative `latest-state.json` contract |
| 2. Mail delta | Initialize evidence arrays; collect Inbox and Sent Items from `WindowStart` through `WindowEnd`; paginate; normalize stable IDs; deduplicate overlap; retain only privacy-minimized fields | Inbox and Sent coverage counts reconcile exactly to exported messages |
| 3. Metadata | Local Outlook COM completes draft and Microsoft To Do metadata after the cloud handoff | Draft and task coverage counts reconcile exactly; no private identifiers or content fields leave process memory |
| 4. Neutral routing | Apply deterministic project rules after collection; create exactly one route record for every evidence stable ID | Each item is `routed`, `ambiguous`, or `unmatched`; no item is silently discarded |
| 5. Projection handoff | Runtime-proven secure Compose and OneDrive `CreateFile` after every collection, routing, and drift gate passes | No projection exists for a partial, duplicate, drifting, privacy-invalid, or failed run |
| 6. Local candidate | Runtime-proven Outlook completion and `scripts/ConvertTo-PortfolioEvidenceDelta.ps1` against the synced projection and pinned bootstrap predecessor | State comparison, canonical hashes, bounded cancellation, routes, and the append-only version `2.0` candidate pass strict validation |
| 7. Validation and promotion | Use the builder's `-PromoteToState` handoff to atomically promote the single matching `latest-state.json` generation | Failed, partial, stale, colliding, or concurrent runs preserve the prior state; no `.building`, `.promoting`, or lock file remains |
| 8. Schedule | Activated after explicit approval and runtime proof; cloud runs Monday-Friday at 07:15, 11:15, 13:15, and 14:15 CET; the signed-in-user desktop task processes each window at :30 with a :45 retry, plus logon | Cloud concurrency remains `1`; local concurrency remains `IgnoreNew`; production remains untouched |

Atomic checkpoint promotion was tested locally on 2026-08-26: a valid delta replaced `latest-checkpoint.json`, left no temporary file, and the promoted run ID and watermark were accepted as the next delta predecessor. The neutral bootstrap checkpoint is outside the repositories under `/GBS IT docs/.local/portfolio-control/checkpoints/` and links to validated snapshot run `7ea19e53-bcf2-4ee0-89b4-6a98eb31a862` at `2026-08-26T07:50:44.5416525Z`. Its 305 bytes were pinned before tenant wiring with SHA-256 `f2a7c74dd833dc8752041b37419e08a70ed0b4db94fea1a7df888ee7b414f423`.

The thread-head and calendar-fingerprint state contract must be defined and tested before Stage 3 is implemented. A run ID and watermark alone are insufficient to distinguish an advanced old conversation or a changed recurring meeting from a newly observed item.

### Authoritative Incremental State

After bootstrap, `/GBS IT docs/.local/portfolio-control/checkpoints/latest-state.json` is the only authoritative predecessor. It combines the successful run/checkpoint with comparison state:

```json
{
  "schemaVersion": "1.0",
  "run": { "runId": "<uuid>", "status": "complete", "exportedAt": "<ISO-8601>" },
  "checkpoint": { "watermark": "<ISO-8601>", "promotedAt": "<ISO-8601>" },
  "sourceDeltaPath": "/GBS IT docs/.local/portfolio-control/candidates/portfolio-evidence-delta-<timestamp>-<runId>.json",
  "threadHeads": [
    { "conversationId": "<opaque Outlook ID>", "currentHeadId": "mail:<stable ID>", "lastObservedAt": "<ISO-8601>" }
  ],
  "calendarFingerprints": [
    { "stableId": "event:<stable ID>", "fingerprint": "sha256:<64 lowercase hex>", "privacyMode": "busyOnly", "start": "<ISO-8601>", "end": "<ISO-8601>", "showAs": "busy", "isAllDay": false, "changeType": "updated", "lastObservedAt": "<ISO-8601>" }
  ]
}
```

State never stores mail subject, sender, recipients, body, attendees, location, event subject, or event body. A cancelled event remains in `calendarFingerprints` with `changeType: cancelled`; it is not silently deleted. Each conversation ID and event stable ID occurs exactly once.

Compare mail threads without using subjects. Group collected messages by non-empty `conversationId`. Within each group, select the latest message by normalized occurrence time, using the stable `mail:` ID as the deterministic tie-break. If the conversation is absent from predecessor state, emit `new` with `previousHeadId: null`. If it is present and the selected stable ID differs from the stored head, emit `advanced` and copy the stored head exactly into `previousHeadId`. If the selected ID equals the stored head, emit no thread transition. Validation rejects empty conversation IDs, an `advanced` transition whose previous head does not match state, and any purported advance whose previous and current IDs are equal.

For each calendar change, build a canonical object in this exact property order before hashing: `stableId`, `privacyMode`, `start`, `end`, `showAs`, `isAllDay`, `subject`, `bodyPreview`. Normalize date-times to ISO 8601 with offsets and booleans to lowercase `true` or `false`. For `busyOnly`, set `subject` and `bodyPreview` to empty strings before canonicalization; never hash the raw connector payload. Serialize the canonical object without whitespace as UTF-8, calculate SHA-256, and emit lowercase `sha256:<64 hex>` as `fingerprint`. Power Automate's native `sha256()` expression failed at runtime in controlled run `08584137764050131802890135725CU25`; keep this calculation in the locally validated PowerShell stage unless an approved hashing action or service reproduces the local synthetic golden values before activation.

Bootstrap uses the separately validated `latest-checkpoint.json` once. The first successful delta creates `latest-state.json`; every later delta must name the state run ID and watermark as its predecessor. `-PromoteToCheckpoint` now fails deliberately because independently advancing it could pair a current watermark with stale comparison state. Use:

```powershell
powershell -NoProfile -File scripts/Test-PortfolioEvidenceDelta.ps1 `
  -Path <candidate-delta.json> `
  -PreviousCheckpointPath <latest-state-or-bootstrap.json> `
  -PromoteToState <latest-state.json>
```

Promotion acquires an exclusive `latest-state.json.lock`, validates the delta, merges exact thread and calendar transitions, validates the complete candidate state, writes `latest-state.json.promoting`, and atomically replaces `latest-state.json`. A concurrent promoter fails before validation. Any stale, replayed, mismatched, duplicate, privacy-invalid, malformed-hash, no-op-transition, lock, or write failure leaves the prior state unchanged and removes temporary files owned by that invocation.

Local integration validation is `powershell -NoProfile -File scripts/Test-PortfolioControlStateIntegration.ps1`. Activation followed successful local validation, a disabled tenant test, authoritative-state promotion, and a validated no-change incremental cycle.

The category-or-content calendar condition was approved and documented on 2026-08-25, but deployment to the live flow is pending an authenticated Power Automate session and the synthetic tests above. Until those tests pass and the saved flow is read back, treat the live collector as category-only and use the authorized live Outlook calendar pass to close the meeting-detail gap.

To pause collection, turn the flow off. This does not alter Outlook or calendar data. For rollback:

1. Turn the flow off before changing files.
2. Restore the previous `latest.json` version through OneDrive version history, or re-promote a previously validated dated candidate.
3. Move or delete only generated files under `/GBS IT docs/icondb/.local/power-automate/`; do not touch repository artifacts.
4. Re-run the local validator against the restored file with an intentionally larger `-MaxAgeHours` only to test structure. Do not call an old file fresh in morning control.
5. Re-enable only after the flow definition and test evidence are reviewed.

Changing recipients, calendars, horizon, staging location, mutation actions, approval actions, sharing, or confirmed delegates requires user approval before implementation.
