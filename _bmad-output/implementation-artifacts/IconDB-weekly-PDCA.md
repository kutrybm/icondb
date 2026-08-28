The terminal process "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" terminated with exit code: 1.
# IconDB Weekly PDCA

**Week:** 2026-08-10 to 2026-08-14
**Prepared for:** Tuesday PO/technical 1:1 and weekly IconDB call
**Prepared by:** Michal Kutryb
**Status:** Active - reconciled 2026-08-13

## Weekly Outcome

Confirm the QA-first FemCare scope and owners, preserve a dated nearest action for every active OU, prepare the QA clean-state and rollback package, and defer OU production execution until the 11 September production correction and subsequent validation pass.

## Plan

### Required Outcomes

1. Record Jyoti's confirmed deployment, refresh, cleanup, and mapping constraints.
2. From Tomita's return on 2026-08-18, confirm the FemCare sample, expected values, business signer, and EECAR treatment by 2026-08-24.
3. Prepare the QA inventory, rollback, reconstruction, and resynchronization package by 2026-08-27 without deleting or uploading data during the coverage gap.
4. Confirm the Enovia QA deployment and its actual data baseline or refresh status, reconcile it with IconDB QA, then switch the sole endpoint. Validate FemCare on 2026-09-02 to 2026-09-07 only if this gate closes.
5. Reconcile CPM-648 Jira status, retain representative routing/MAE evidence, and close restart governance.
6. Execute the dependency-based recovery schedule while preserving one recovery per late baseline.
7. Keep FC NA, FC EU, Oral Care EU, FemCare EU, LA, AAC, Trident, and SGX commitments visible in the SharePoint master CPS and its role views.

### Proposed Recovery Sequence

| Step | Proposed target | Requested owner | Evidence required | Status |
|---|---|---|---|---|
| Reconcile CPM-648 Jira status | Wed 2026-08-12 | Tommy / Steve | Jira reflects the confirmed production test or contains an explanatory comment | Done; live Jira is `Done`, updated 2026-08-12 |
| Send one correct FemCare SIT payload | Wed 2026-08-12 | Michal / Steve | Exact JSON/request payload received by Jyoti | Done; Steve sent the sample and Jyoti replied |
| Record Jyoti's Enovia constraints | Thu 2026-08-13 | Michal / Jyoti | Deployment dates, refresh/cutoff dates, cleanup feasibility, and mapping gap retained | Done; authoritative reply reviewed |
| Confirm QA-first FemCare scope and signer | Tue-Mon 2026-08-18 to 2026-08-24 | Tommy / Steve / Jyoti / FemCare | One to three samples, expected values, signer, EECAR treatment, and stop conditions | Added to master CPS row 222 |
| Prepare QA clean-state and resynchronization package | Tue-Thu 2026-08-18 to 2026-08-27 | Tommy / Steve / Jyoti / Michal | Inventories, reconstruction source, rollback, delta handling, and endpoint evidence plan | Added to master CPS row 225 |
| Confirm QA deployment, baseline, and switch sole endpoint | Tue 2026-09-01 | Jyoti / Tommy / Steve | QA deployment evidence; written refresh/no-refresh and cutoff/scrub confirmation; reconciled baseline; one endpoint; successful connectivity | Added to master CPS row 223; test date conditional on gate |
| Validate FemCare in Enovia QA | Wed-Mon 2026-09-02 to 2026-09-07 | Michal / FemCare / Jyoti / Steve / Tommy | Request/result, MAE ID, routing, files, errors, and written business sign-off | Added to master CPS row 224 |
| Retain representative production validation evidence and failure/rollback route | Thu 2026-08-13 | Michal / Tommy / Jyoti | Sample identifier, approval, production-Enovia result, error route, rollback owner | Added to master CPS; not started |
| Confirm cross-OU restart authority and criteria | Fri 2026-08-14 | Tommy / Tripolina, accountability to confirm | Named decision owner and written criteria | Added to master CPS; depends on retained evidence |
| Execute first recovery activities | From Wed 2026-08-12 | Named CPS owners | Master recovery rows and completion evidence | 67 late baselines / 67 recovery rows |
| Upload priority OUs to production | After go decision | Michal | Upload totals and exception log | Conditional |

### Nearest OU Commitments

| OU | Nearest commitment | Due | Next gate |
|---|---|---|---|
| FC NA | Confirm recovery sample/acceptance owner and reconcile seven failed production records | 2026-08-24 | Recovery pilot 2026-09-17 to 2026-09-18 |
| FC EU | Michal validates the corrected template and upload-ready pack | 2026-08-25 | Controlled upload 2026-09-17 to 2026-09-18 |
| FemCare EU | Confirm QA samples, expected results, signer, and EECAR treatment | 2026-08-24 | Conditional QA validation 2026-09-02 to 2026-09-07 |
| Oral Care EU | Prepare OCEU_534/OCEU_318 and confirm the variable-text BVE/AAC route | 2026-08-31 | Controlled validation from 2026-09-17 |
| LA | Realign with Dennis Mendez and the LA Transformation Team; schedule the leadership session and keep Paula Diaz involved | 2026-08-28 | Confirm the engagement route, then align detailed activation sequencing with shared program gates |

The earlier Thu-Fri Aug 14-15 wording is not used here because 2026-08-15 is Saturday. Any work beyond Friday requires an explicitly accepted date.

### Definition Of The QA Gate

- Integration Type is accepted by Enovia in the required structure.
- Required Brand attribute is present.
- Region maps to the intended Enovia structure.
- MAE number is generated where expected.
- Icon reaches the intended copy list.
- Failed records and error details are visible.
- Sample identifiers and results are retained as evidence.
- Rollback or correction route is agreed before production restart.
- IconDB sends to only one Enovia environment at a time; SIT and QA are never configured simultaneously.
- The returned MAE identifier is retained with the source environment so SIT and QA identity cannot be confused.
- Enovia QA refresh/no-refresh status, effective data cutoff, scrub behavior, and availability are confirmed in writing; the resulting Enovia QA baseline is reconciled with IconDB QA before endpoint switch.

## Do

Update during the week with dated evidence.

| Date | Activity completed | Evidence/link | Result |
|---|---|---|---|
| 2026-08-10 | Live Jira baseline reviewed through MCP | CPM-648 and related issues | CPM-648 is Urgent and Approved for Prod Release |
| 2026-08-11 | Controlled production IconDB approval path tested through Enovia | User-confirmed production test and CPS evidence review | Technical path confirmed; CPM-648 Jira remains stale |
| 2026-08-11 | Recovery rows added for all remaining late baselines | Authoritative SharePoint CPS read-back | 67 late baselines / 67 recoveries after training correction; zero broken references |
| 2026-08-12 | Missing activation controls added to master CPS | Current rows 227-228 in authoritative SharePoint CPS | Validation/rollback evidence gate and dependent restart-authority gate scheduled |
| 2026-08-12 | Enovia SIT/production and IconDB QA/production cleanup transcript reviewed | `Enovia SIT_Prod and IconDB dev_QA_Prod icons cleanup.vtt` | Immediate path changed from generic cleanup to payload analysis, SIT validation, endpoint switch, and QA test |
| 2026-08-12 | Seven transcript-derived actions added to the authoritative CPS | Read-only CPS reopen after save | Dates and dependencies verified; 67 late baselines / 67 recoveries; zero broken references |
| 2026-08-12 | Role-focused dependency views and live Gantts generated from the master | Common BU; FC NA, FC EU, OC EU, Fem EU, LA; AAC; IconDB; Enovia tabs | All nine views use business-readable labels, master-linked action/date formulas, plain-language dependencies and replanning notes, and four live Gantt rules. Read-only validation confirmed all source references and master integrity. |
| 2026-08-12 | Power Automate scheduled-run history reviewed | Flow `277e018f-85cd-4917-9ab4-94e2bffed162` | Flow is `On`, but no 2026-08-12 run occurred; mail/calendar coverage unavailable |
| 2026-08-13 | Jyoti's full downloaded reply reviewed | Local `.msg` authoritative evidence | SIT-first sign-off is no longer justified; QA-first path adopted based on deployment, refresh, cleanup, mapping, and coverage constraints |
| 2026-08-13 | CPM-648 live Jira status refreshed | Jira MCP | Card is `Done`, closing the prior release-status contradiction |
| 2026-08-13 | Morning snapshot rerun validated and promoted | Candidate `022c7754-03c9-4b84-a8d2-94aea990b43e` | 32 messages and 195 contained events available; zero relevant calendar events |
| 2026-08-13 | Authoritative CPS rows 220-226 rebaselined to QA-first | SharePoint master read-only verification | Readiness 18-24 Aug; preparation 18-27 Aug; endpoint 1 Sep; QA validation 2-7 Sep; 67 late / 67 recovery |
| 2026-08-13 | Official Enovia SIT environment plan reviewed | `Fw_ Enovia SIT Environment Plan .msg`; Ruby Yu formal notice | SIT unavailable 31 Aug-13 Sep; QA required for 2022x testing; new SIT opens 14 Sep from 28 Aug production copy; no QA copy stated |
| 2026-08-13 | Revised QA-first FemCare and AAC plan sent to the team | Sent email; Bernard and Emilian included | Responses due Monday 17 Aug; Prod deployment 11 Sep; controlled Prod validation 14-15 Sep; restart/AAC Rule Manager handoff decision 16 Sep |
| 2026-08-13 | Authoritative CPS production and AAC gates rebaselined | SharePoint master rows 227-228, read-only reopen and CPS validator | Production validation 14-15 Sep; dependent restart authority and AAC Rule Manager handoff 16 Sep; workbook contract passed |
| 2026-08-13 | OU and AAC/BVE recovery paths reconciled with current Outlook commitments | SharePoint master rows 170, 205, 207, 211, 217, 231, 235, 237, 265, 267, 271, 273, 275, 277, 281, 283, 293, 297, and 301-303 | Nearest action/date is explicit for each OU; production execution follows the 16 Sep gate; BVE training separated from open AAC rules and implementation confirmation |
| 2026-08-13 | BU, FC NA, FC EU, OC EU, and AAC views regenerated from the master | Read-only formula-link and workbook validation | All affected role views point to the updated master rows; 67 late baselines / 67 recoveries retained |
| 2026-08-13 | Broad Program Update revised in Outlook Drafts | `Icon Database Program Update 13.08.26` | Compact OU plan, CPS link, and explicit Enovia/IconDB/AAC/BVE dependencies included; saved and not submitted |
| 2026-08-13 | LA engagement route corrected | SharePoint master row 379 and regenerated BU/LA views | Realignment with Dennis Mendez and the LA Transformation Team scheduled for 24-28 Aug; Paula Diaz remains involved for demos and operations availability |
|  |  |  |  |

## Check

### Plan Versus Actual

| Planned result | Actual result | Variance/root cause | Confidence |
|---|---|---|---|
| CPM-648 released and available for validation | Successful production path confirmed; Jira is now `Done` | No remaining status variance | High |
| Enovia routing and production visibility proven | Controlled icon confirmed in production Enovia | Evidence package and rollback/failure route not yet retained as a gate | High on observed result |
| Recovery schedule covers all late baselines | 67 late baselines and 67 recovery rows | None in coverage; execution evidence now required | High |
| Production restart decision made | Pending | Accountable cross-OU approver and criteria remain unresolved | High |
| FemCare execution path ready | QA-first path scheduled; sample, signer, EECAR treatment, and rollback package remain open | Owner confirmations and QA readiness are now the controlling dependencies | High |
| Enovia environment sequence agreed | QA changes 31 Aug; QA is required during SIT outage; production changes 11 Sep; earliest planned business-day production test is 14 Sep | Official plan confirms SIT timing but not QA baseline | High on dates; unresolved QA baseline |

### Live Jira Baseline

| Jira | Current status | Priority | Assignee | Last updated |
|---|---|---|---|---|
| CPM-648 | Done | Urgent | Stephen Ferda | 2026-08-12 |
| CPM-641 | To Do | High | AdrianValentin Tomita | 2026-07-24 |
| CPM-369 | Approved for Prod Release | Medium | Unassigned | 2026-07-27 |
| CPM-439 | To Do | Medium | Stephen Ferda | 2026-02-26 |
| CPM-471 | To Do | Medium | Stephen Ferda | 2026-03-13 |
| CPM-496 | To Do | Medium | AdrianValentin Tomita | 2026-06-10 |
| CPM-497 | To Do | Medium | AdrianValentin Tomita | 2026-07-03 |
| CPM-555 | To Do | Medium | AdrianValentin Tomita | 2026-08-06 |
| CPM-590 | To Do | Medium | AdrianValentin Tomita | 2026-06-10 |
| CPM-591 | To Do | Medium | AdrianValentin Tomita | 2026-06-11 |
| CPM-612 | In Progress | Medium | AdrianValentin Tomita | 2026-06-26 |

Refresh this table through Jira MCP before each Tuesday preparation. Do not use downloaded Jira exports.

## Act

Complete after QA results and weekly decisions.

| Corrective action or decision | Owner | Due | State | Related Jira |
|---|---|---|---|---|
| Reconcile CPM-648 Jira with successful production evidence | Tommy / Steve | 2026-08-12 | Done | CPM-648 |
| Retain validation evidence and rollback/failure route | Michal / Tommy / Jyoti | 2026-08-13 | Added to master CPS | CPM-648 / Enovia evidence |
| Confirm cross-OU restart authority and criteria | Tommy / Tripolina, accountability to confirm | 2026-08-14 | Added to master CPS; dependent | Recovery gate |
| Send the correct FemCare SIT payload and retain the handoff | Michal / Steve | 2026-08-12 | Done; response received from Jyoti | Enovia / IconDB integration |
| Confirm QA-first sample, signer, and EECAR handling | Tommy / Steve / Jyoti / FemCare | 2026-08-24 | Scheduled from Tomita's Tuesday return | Enovia / IconDB integration |
| Prepare QA clean-state, rollback, and resynchronization evidence | Tommy / Steve / Jyoti / Michal | 2026-08-27 | Scheduled; no destructive action during coverage gap | Enovia / IconDB integration |
| Confirm QA deployment and baseline, switch sole endpoint, then validate FemCare | Jyoti / Tommy / Steve / FemCare / Michal | 2026-09-07 | QA-first path applied; execution conditional on written QA baseline and reconciliation | Enovia / IconDB integration |
| Prepare concise written delegation for Tommy and Jyoti during Michal's absence | Michal | 2026-08-14 | Added after current morning run | Operating control |
| Correct the Power Automate recurrence, approve one run time, and verify the next scheduled run | Michal | 2026-08-12 | Open automation exception; runbooks conflict between 09:00 and 07:30 | Morning control |
| Select first post-stabilization requirement for readiness work | Michal / Tommy | 2026-08-14 | Proposed | CPM-497 / CPM-590 / CPM-214 |

## Decisions Required

| Decision | Decision owner | Needed by | Impact if late | Outcome |
|---|---|---|---|---|
| Is any non-gating SIT smoke test worth the effort? | Tommy / Steve / Jyoti | 2026-08-18 | Could consume scarce capacity without resolving EECAR or QA readiness | Default no; require a narrow written objective to proceed |
| Who gives the final cross-OU restart decision and against which criteria? | Tommy / Tripolina, accountability to confirm | 2026-08-14 | No controlled production restart | Pending |
| What is the final AAC sign-off route? | Rachel / Emilian | Before AAC readiness claim | AAC cannot become delivery-ready | Pending within Rachel/Emilian camp |
| Which requirement receives shared development capacity after stabilization? | Michal / Tommy | 2026-08-14 | No credible next-cycle forecast | Pending |
| What supported EECAR mapping will be used in QA? | Lauren / Jyoti | 2026-08-24 | EECAR cases cannot enter the first QA gate safely | Pending feasibility check; outside September scope |
| Who signs FemCare QA and which samples are used? | Ola / Jakub / FemCare | 2026-08-24 | No accepted business result | Pending |
| Will QA receive a production copy/refresh, and what data baseline is safe for testing? | Jyoti / Enovia team | Before endpoint switch | Endpoint switch may connect IconDB QA to an unknown or mismatched Enovia QA population | No official QA refresh plan shared; pending written confirmation |

## Risks And Dependencies

| Risk/dependency | Current evidence | Owner | Next action | State |
|---|---|---|---|---|
| EECAR is outside the September Enovia change scope | Jyoti written reply 2026-08-13 | Lauren / Jyoti | Confirm supported treatment by 24 Aug or exclude EECAR from first QA gate | Active critical dependency |
| Validation evidence and failure/rollback route are not retained as one gate | Proposal-to-master comparison | Michal / Tommy / Jyoti | Complete new master action | Active |
| Cross-OU restart authority and criteria are not named | Existing OU go/no-go rows are local to each activation | Tommy / Tripolina | Complete dependent master action | Active |
| Shared capacity with Touchless reduces predictability | PO/technical operating context | Michal / Tommy | Agree explicit next-cycle priority | Open |
| AAC tagging/readiness remains outside the PO training scope | User correction: all non-LA training complete; AAC belongs to Rachel/Emilian | Rachel / Emilian | Confirm final sign-off route and evidence | Open |
| Tripo unavailable until end of August | PO update | Michal | Record decisions; brief after return | Active |
| SIT refresh on 31 Aug uses a 28 Aug production copy and returns 14 Sep without images | Jyoti written reply 2026-08-13 | Tommy / Steve / Jyoti / Michal | Use QA-first path and complete repeatable resynchronization/delta controls | Active external schedule |
| QA is mandated for 2022x testing during the SIT outage, but its refresh/baseline is not specified | Ruby Yu official plan; Jyoti says no official QA plan shared | Jyoti / Enovia team / Tommy / Steve | Confirm refresh/no-refresh, cutoff, scrub scope, stable availability, and reconcile against IconDB QA before switching endpoint | Active hard gate |
| Production correction is not available until 11 Sep | Jyoti written reply 2026-08-13 | Jyoti / Tommy / Steve | Confirm deployment and test no earlier than 14 Sep | Active critical date |
| AAC cannot complete until production IconDB identities replace Graphics Library references in Rule Manager | Technical Activation thread; Bernard assigned AAC leadership to Emilian | Emilian / Tommy / Steve | After production validation, upload icons with final names/IDs, migrate Rule Manager rules, then run AAC E2E | Active downstream gate |
| Simultaneous SIT and QA targets can confuse IconDB's single retained MAE identifier | Current design | Tommy / Steve | Keep one endpoint and switch to QA only after deployment evidence | Active control |
| Scheduled snapshot failed closed on a changing calendar record; manual rerun succeeded | 2026-08-13 Power Automate run and validated local candidate | Michal | Verify the next scheduled 09:00 occurrence; retain two-pass fingerprint validation | Monitoring |

## Weekly Meeting Agenda

1. Confirm last week's decisions and completed actions.
2. Review CPM-648 release and Enovia correction evidence.
3. Close the QA gate, cleanup, and production restart decisions.
4. Confirm owners and dates for unresolved dependencies.
5. Select the next requirement to prepare for sign-off and estimation.
6. Review the parking lot and assign follow-up routes.

## Parking Lot

Use this table visibly during the meeting. Capture the topic before redirecting discussion.

| Topic | Raised by | Why parked | Follow-up owner | Follow-up route/date |
|---|---|---|---|---|
|  |  |  |  |  |

Suggested introduction:

> We have a small number of delivery decisions to close today. I will capture important adjacent topics in the parking lot so they are not lost, and we will assign the right follow-up before the end.

## Meeting Record Processing

After each recorded meeting:

1. Store the transcript only in an approved location and redact sensitive content before committing it.
2. Classify each statement as explicitly agreed, proposed, inferred, or unresolved.
3. Update Decisions Required, Act, Risks and Dependencies, and Parking Lot.
4. Refresh Jira fields live through MCP.
5. Produce concise minutes and the next pre-read from this PDCA.
