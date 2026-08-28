# IconDB Recovery Baseline

**As of:** 10 August 2026
**Status:** Proposed until accepted by each requested owner
**Purpose:** Bridge the historical CPS to an executable recovery plan and weekly PDCA.

## Operating Rules

- `Project schedule` remains historical evidence. Late historical rows are not active predecessors.
- Continuing work receives a replacement ID, proposed date, owner, evidence gate, and blocker category.
- A successor references only replacement IDs.
- LA cannot start until FC NA, FC EU, Fem EU, and Oral EU have all passed production acceptance.
- AAC/SGX, Claims Studio/RTA, family lifecycle, and operability are governed separately from the manual OU activation gate.
- Attribution identifies the accountable team or dependency, not individual blame.

## Dependency Network

| ID | Workstream | Predecessor(s) | Proposed dates | Required outcome |
|---|---|---|---|---|
| R01 | Diagnose FC NA PROD to Enovia failure | None | 10-14 Aug | Written root cause and named fix owner |
| R02 | Resolve FC EU upload limit/batch method | None | 10-14 Aug | Supported batch rule and error handling |
| R03 | Deploy integration correction | R01 | 17-19 Aug | Deployment/version/rollback evidence |
| R04 | Confirm Enovia mapping | R01 | 17-19 Aug | Written mapping and Enovia evidence |
| R05 | Define representative test and rollback | R02, R03, R04 | 20 Aug | Agreed sample and pass/fail checklist |
| R06 | Run end-to-end QA | R05 | 21-24 Aug | IconDB to Enovia to POA/Copy Manager evidence |
| R07 | Run controlled FC NA PROD recovery pilot | R06 | 25-26 Aug | MAE and correct routing for agreed records |
| R08 | Production restart go/no-go | R07 | 27 Aug | Named approver and signed decision |
| N01 | Prepare FC NA activation | R08 | 28 Aug-1 Sep | Checklist, reconciled data, support and exceptions |
| N02 | Accept FC NA in production | N01 | 2-4 Sep | Production, Enovia and user acceptance evidence |
| E01 | Prepare FC EU activation | R02, R08 | 28 Aug-4 Sep | Split pack and complete checklist |
| E02 | Accept FC EU in production | E01 | 7-11 Sep | QA/UAT, PROD, Enovia and user acceptance |
| F01 | Close Fem EU audit and attributes | R08 | 28 Aug-4 Sep | Approved list and closed discrepancies |
| F02 | Complete Fem EU QA/SIT and BU sign-off | F01, R06 | 7-11 Sep | Search, attachment, attributes and BU sign-off |
| F03 | Accept Fem EU in production | F02 | 14-18 Sep | PROD evidence and acceptance |
| O01 | Prepare Oral EU activation | R08 | 28 Aug-4 Sep | Named lead, data, checklist and acceptance owner |
| O02 | Run Oral EU QA/UAT | O01, R06 | 7-11 Sep | Standard acceptance evidence and defect list |
| O03 | Accept Oral EU in production | O02 | 14-18 Sep | PROD evidence and live-user acceptance |
| G01 | Four-OU production acceptance gate | N02, E02, F03, O03 | 21 Sep | Four signed acceptance records |
| L01 | Select and prepare first LA OU | G01 | 22-25 Sep | Named OU/lead, complete pack and test plan |
| L02 | Run first LA activation and acceptance | L01 | 28 Sep-9 Oct | QA/UAT, PROD and regional acceptance |
| M01 | Reframe/reschedule 16-Sep PL review | R08 | 28 Aug-1 Sep | Recovery update scope or date after G01 |
| C01 | Select post-stabilization development priority | R08 | 28 Aug-1 Sep | One priority, reserved capacity and deferred work |
| C02 | Complete family lifecycle decision/release | C01 | 2-11 Sep | CPM-369 acceptance and signed rules |
| A01 | Establish AAC/SGX readiness ownership | C01 | 2-18 Sep | Owner, Smart PDF option, files and criteria |
| X01 | Govern Claims Studio/RTA integration | C01 | 2-11 Sep | Signed workflow, owners, test plan and capacity |
| S01 | Govern security/logging remediation | R08 | 14 Sep-9 Oct | Findings disposition, scope, owners and dates |

## Leadership Decisions

- Escalate if Canvas/Enovia diagnosis or supported FC EU batch method is absent by 14 August.
- Name the production restart approver and acceptable residual-risk threshold before `R08`.
- Name one accountable lead and acceptance owner for each priority OU.
- Decide whether the 16 September PL session is a recovery update or a results review after `G01`.
- Resolve the IconDB versus Touchless capacity trade-off before downstream development starts.
- Keep AAC/SGX and Claims Studio/RTA outside the OU critical path until their owners, process boundaries, evidence, and capacity are explicit.

## Evidence Boundary

The baseline uses live Jira as of 10 August, July/August 2026 emails, the OU Activation Checklist, the AAC Readiness Note, vacation backup notes, and the historical CPS. No current 2026 transcript was found; March-April 2025 recordings were excluded from August commitments.
