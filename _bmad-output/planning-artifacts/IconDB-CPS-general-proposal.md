# IconDB Critical Path Schedule - General Proposal

**Version:** 0.2
**As of:** 2026-08-13
**Owner:** Michal Kutryb, Product Owner
**Purpose:** Provide a stable, management-level critical path. Detailed weekly actions are maintained in the IconDB weekly PDCA.

## Product Outcome

Establish IconDB as the governed source for packaging icons, with reliable delivery to Enovia and controlled reuse by OUs and downstream consumers.

## Current Position

- IconDB is live and the first production uploads have been completed.
- Wider uploads are paused while the Enovia data-routing path is corrected and validated.
- A controlled production test completed the IconDB approval path and confirmed the icon in production Enovia. CPM-648 is now `Done` in live Jira.
- The prior SIT-first FemCare path is superseded. Enovia single-string support reaches SIT on 19 August, QA on 31 August, and production on 11 September. EECAR is outside the September change scope and requires a separate feasibility answer by 24 August.
- Ruby Yu's official environment plan confirms that SIT is unavailable from 31 August until 14 September and directs 2022x testing to QA. The 28 August production database copy is explicitly for the new SIT; no official QA production-copy plan is confirmed.
- The controlled path is QA-first: confirm sample, signer, region treatment, and QA refresh/baseline; prepare QA inventory/rollback; reconcile IconDB QA with the confirmed Enovia QA baseline; switch the sole endpoint only after those gates; validate FemCare in QA on 2-7 September if ready.
- OU scaling should resume only after representative validation evidence, failure/rollback handling, and accountable restart criteria are retained in the master CPS.
- Family management, approval workflow, duplicate detection, and AAC readiness remain subsequent delivery gates.

## Critical Path

| Phase | Outcome | Exit gate | Current position |
|---|---|---|---|
| 0. Foundation and go-live | IconDB environments and initial production capability available | First controlled production upload completed | Complete |
| 1. Production stabilization | Reliable IconDB-to-Enovia routing and recoverable upload process | Production evidence retained; rollback/failure route documented; production upload restart authority and criteria confirmed | Active - technical path proven; control evidence and restart governance remain |
| 2. Controlled OU activation | Priority OUs onboarded through a repeatable service process | Upload pack validated; OU acceptance recorded; production usage measured | Paused behind Phase 1 gate |
| 3. Icon governance | Families, change management, approvals, roles, and duplicate controls operate as one governed flow | Requirements signed off, estimated, delivered, and validated | Requirements/backlog stage |
| 4. Downstream adoption | AAC and other consumers can use governed IconDB content reliably | AAC ownership, test evidence, integration criteria, and readiness sign-off confirmed | Dependency not yet confirmed |
| 5. Operational maturity | Sustainable monitoring, security, support, and auditability | Logging, performance, security findings, support ownership, and service measures agreed | Foundation items remain open |

## Workstreams And Gates

### 1. Production And Enovia Integration

**Objective:** Restore confidence in the live data flow before scaling uploads.

- Reconcile CPM-648 Jira status with the successful production-to-Enovia test evidence.
- Confirm EECAR/Europe mapping or explicitly exclude unsupported EECAR cases from the first QA gate.
- Prepare the QA clean-state inventory, rollback, reconstruction source, and refresh-delta handling by 27 August.
- Confirm the 31 August Enovia QA deployment plus written QA refresh/no-refresh, cutoff, scrub scope, and stable baseline; reconcile it with IconDB QA before switching the sole endpoint on or after 1 September.
- Validate MAE generation and copy-list routing using agreed FemCare QA samples on 2-7 September.
- Retain representative production validation evidence and define rollback/failure handling before mass upload.
- Confirm cross-OU production restart authority and decision criteria.
- Treat CPM-439, CPM-471, CPM-218, CPM-226, and CPM-184 as related backlog requiring current relevance review rather than assuming their older Jira descriptions represent the new incident.

**Gate:** Enovia QA's actual baseline is confirmed and reconciled before endpoint switch; joint QA evidence demonstrates correct routing; the production correction is confirmed and deployed on 11 September; a production test passes on or after 14 September; and named owners approve restart. AAC follows only after production icons have stable IconDB names/IDs, Rule Manager references are migrated from Graphics Library, and Emilian's team completes E2E validation.

### 2. OU Activation

**Objective:** Move from one-off uploads to a repeatable OU onboarding service.

- FC NA confirms its recovery sample and acceptance owner by 24 August, then runs a controlled production recovery pilot after the 16 September restart gate.
- Michal validates the corrected FC EU template by 25 August; controlled upload follows the restart gate.
- FemCare EU confirms QA samples, expected results, signer, and EECAR treatment by 24 August for conditional QA validation on 2-7 September.
- Oral Care EU prepares OCEU_534 and OCEU_318 and confirms the variable-text BVE/AAC route by 31 August; controlled validation follows the restart gate.
- LA has already received program introductions. Realign the next step with Dennis Mendez and the LA Transformation Team on 24-28 August, retain Paula Diaz for demos and operations-team availability, and then agree the detailed activation sequence against the shared program gates.
- Track icons uploaded per OU and OUs actively using IconDB.
- Use one activation checklist and one accepted upload template.
- Record OU acceptance and unresolved data-quality exceptions.

**Gate:** Each OU has validated data, trained users, confirmed support, and documented go/no-go.

### 3. Family And Lifecycle Management

**Objective:** Manage icon families and changes without breaking downstream data integrity.

- Complete and validate Icon DB Families (CPM-369), currently approved for production release.
- Finalize Family Rep change management (CPM-496).
- Finalize Family Logic template changes (CPM-497).
- Confirm OU-region family behavior (CPM-555).

**Gate:** Signed-off business rules, technical estimate, test evidence, and production acceptance.

### 4. Approval And Duplicate Controls

**Objective:** Introduce a clear approval gate before scaling self-service use.

- Convert approval placeholders CPM-590 and CPM-591 into implementable requirements.
- Confirm Editor permissions and control boundaries under CPM-647.
- Reassess duplicate controls CPM-214, CPM-215, and CPM-217 as one approval-gate capability rather than three isolated features.

**Gate:** Named approvers, approved workflow, acceptance criteria, estimate, and test plan exist.

### 5. AAC And Downstream Readiness

**Objective:** Establish an evidence-based path from IconDB to AAC.

- Rachel and Emilian own the AAC tagging/readiness stream; they must confirm the final sign-off route within their camp.
- Use Trident and SGX as the BVEs; historical SGK/SGS names refer to the merged SGX organization.
- Confirm the matching value, Smart PDF tagging option, embedded-versus-linked logic, sign-off owner, and Rule Manager migration owner by 31 August.
- BVE training is complete. Trident and SGX must confirm implementation readiness after AAC publishes the final matching/tagging decision.
- After the production restart gate, migrate Rule Manager references from Graphics Library to stable production IconDB names/IDs, execute AAC E2E, and retain accountable sign-off.
- Separate AAC decisions from technical implementation estimates.

**Gate:** Written ownership, accepted test files, completed test evidence, and readiness decision.

All required role-based training materials and all non-LA training are complete. LA training remains part of the activation schedule and must not be generalized as a broader training gap.

### 6. Operability, Security And Support

**Objective:** Make IconDB supportable and auditable as adoption increases.

- Resolve external-link performance under CPM-641.
- Review automated offensive security results under CPM-612.
- Define the minimum logging scope behind CPM-499.
- Confirm service ownership, incident route, monitoring, and release evidence.

**Gate:** Operational owners and minimum controls are documented and accepted.

## Governance And Cadence

| Forum | Purpose | Core participants | Output |
|---|---|---|---|
| Tuesday PO/technical 1:1 | Prepare priorities, technical questions, and decisions | Michal, Tommy | Agreed agenda and proposed weekly commitments |
| Weekly IconDB call | Close delivery decisions and dependencies | Existing IconDB participants | Decisions, actions, risks, parking lot |
| Technical consultation | Estimate or resolve ready technical items | Tommy, Steve, invited only when needed | Estimate, feasibility decision, technical action |
| AAC/Enovia decision follow-up | Resolve cross-team sign-off or data-contract questions | Named decision owners | Written decision and due date |

Canvas Jira remains the engineering source of truth. The weekly PDCA records the operating plan, evidence, decisions, and actions without duplicating the development backlog.

## Success Measures

- Icons successfully uploaded and routed per OU.
- OUs onboarded and actively using IconDB.
- First-pass successful Enovia routing rate.
- Open decisions past their required date.
- Requirements ready for estimation versus awaiting sign-off.
- Planned versus completed weekly commitments.
- Production incidents and average time to resolution.

## Evidence Rules

- Jira status, priority, assignee, and update date are read live through Jira MCP.
- Email, meeting, and test evidence may explain context but must not silently overwrite Jira state.
- Proposed dates remain proposals until the named owner accepts them.
- Meeting statements are classified as agreed, proposed, inferred, or unresolved.
- Detailed weekly actions belong in the PDCA, not in this general CPS.
