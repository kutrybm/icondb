# IconDB CPS Preview - 2026-08-11

**Mode:** Review only
**Workbook mutation:** None
**Evidence source:** Live Jira MCP query prepared for this one-time preview
**Historical design only:** This preview assumed a controlled SharePoint status list. That source was rejected for the current workflow; use human-reviewed live Jira MCP plus approved non-Jira evidence and direct master-workbook validation.

## Decision

No Automation Map rows are approved or active yet. The preview found six exact Jira-key families in the archived CPS workbook, but each Jira issue maps to three distinct baseline rows: Dev, QA, and Prod. Applying one Jira status category to all three phases would incorrectly collapse phase progress. Recovery estimates and dependencies are also not approved.

The Office Script now identifies a baseline row by exact task text plus baseline start and end, so row insertion cannot redirect later updates to the wrong phase.

## Matched Candidates

| Jira | Jira status | Jira category | Exact CPS task | CPS phases and baseline dates | Calculated on 2026-08-11 | Active |
|---|---|---|---|---|---|---|
| CPM-369 | Approved for Prod Release | In Progress | `[to update] Icon DB Families (CPM-369)` | Dev 2026-06-08 to 2026-06-18; QA 2026-06-18 to 2026-06-28; Prod 2026-06-28 to 2026-07-08 | Each selected non-done phase would be Late | No |
| CPM-555 | To Do | To Do | `Icon Family Change Management (OU-Region Logic) (CPM-555)` | Dev 2026-06-22 to 2026-07-02; QA 2026-07-02 to 2026-07-12; Prod 2026-07-12 to 2026-07-22 | Each selected non-done phase would be Late | No |
| CPM-497 | To Do | To Do | `Family Logic - Template update (CPM-497)` | Dev 2026-06-22 to 2026-07-02; QA 2026-07-02 to 2026-07-12; Prod 2026-07-12 to 2026-07-22 | Each selected non-done phase would be Late | No |
| CPM-496 | To Do | To Do | `Family Rep Change Mgmt (CPM-496)` | Dev 2026-06-22 to 2026-07-02; QA 2026-07-02 to 2026-07-12; Prod 2026-07-12 to 2026-07-22 | Each selected non-done phase would be Late | No |
| CPM-590 | To Do | To Do | `[Placeholder] Icon Approval Interface (CPM-590)` | Dev 2026-06-22 to 2026-07-02; QA 2026-07-02 to 2026-07-12; Prod 2026-07-12 to 2026-07-22 | Each selected non-done phase would be Late | No |
| CPM-591 | To Do | To Do | `[Placeholder] OU specific approvers for Icons (CPM-591)` | Dev 2026-07-01 to 2026-07-11; QA 2026-07-11 to 2026-07-21; Prod 2026-07-21 to 2026-07-31 | Each selected non-done phase would be Late | No |

`Approved for Prod Release` remains `In Progress`; it is not evidence of `Done`.

## No Exact CPS Match

These queried issues have no CPS task containing the same Jira key and are excluded:

| Jira | Jira status | Jira category | Summary |
|---|---|---|---|
| CPM-214 | To Do | To Do | P-Hashing Duplicate Detection Logic |
| CPM-439 | To Do | To Do | Bulk Update not sent to Enovia |
| CPM-471 | To Do | To Do | IDB Mass Update errors |
| CPM-612 | In Progress | In Progress | Automated Offensive Security Testing Results |
| CPM-641 | To Do | To Do | IconDB external link is very slow |
| CPM-648 | Approved for Prod Release | In Progress | IconDB - Data structure change |

## Evidence Freshness

At preview time, CPM-555 and CPM-648 had been updated within the proposed 24-hour unattended freshness window. The remaining queried Jira records were older than 24 hours. They can inform this human-reviewed preview but must not set `statusSourceComplete: true` in the daily flow until the controlled SharePoint records have current evidence and approval.

## Approval Needed

1. Define how Jira workflow states map separately to Dev, QA, and Prod CPS phases, or provide one Jira key per phase.
2. Approve which phase rows enter the Automation Map.
3. Approve one recovery ID, estimated workdays, predecessors, and `ANY`/`ALL` dependency mode for every selected late row.
4. Populate fresh approved records in `IconDB CPS Status Source` before enabling the 08:00 flow.

Until those decisions are recorded, preview/apply must fail closed and the SharePoint workbook remains unchanged.
