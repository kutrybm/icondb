# IconDB Meeting Summary - Jyoti Mishra And Adrian Tomita

**Date:** 2026-08-12
**Participants:** Michal Kutryb, Jyoti Mishra, Adrian "Tommy" Tomita
**Source:** `Enovia SIT_Prod and IconDB dev_QA_Prod icons cleanup.vtt`
**Purpose:** Agree the safe sequence for FemCare validation, the Enovia SIT-to-QA transition, and handling of future Enovia environment refreshes.

> **Superseded planning note, 2026-08-13:** Jyoti's subsequent written reply confirmed QA deployment on 31 August, production deployment on 11 September, EECAR outside September scope, and SIT refresh on 31 August. Ruby Yu's official plan confirms SIT is unavailable until 14 September and directs 2022x testing to QA, but it does not state that QA receives the 28 August production copy. The SIT-first sequence below remains historical; the current QA-first path requires written QA-baseline confirmation before endpoint switch or testing.

## Executive Summary

The team agreed to use the remaining life of the current Enovia SIT to validate the FemCare payload, then switch IconDB completely from Enovia SIT to Enovia QA before beginning QA testing. IconDB must not send to SIT and QA at the same time because it retains one returned MAE identifier and cannot reliably distinguish two environment responses.

The current Enovia SIT is decommissioned on 2026-08-31. Ruby Yu's formal plan confirms no SIT is available until the new 2026x SIT opens on 2026-09-14 from a production database copy taken on 2026-08-28. Testing requiring 2022x must use QA from 31 August. The plan does not confirm a production copy into QA.

The refresh preserves production metadata and MAE identifiers but removes files and images. This creates a repeatable synchronization problem: the refreshed Enovia non-production environment can contain metadata that no longer matches the files and release state in IconDB QA. A controlled reconciliation and re-release or bulk-load process is therefore required.

## Agreed Sequence

1. Michal sends Jyoti one correct FemCare SIT JSON/request payload.
2. Jyoti performs field-level analysis and identifies any technical correction needed for the September Enovia change window.
3. The team completes and retains FemCare SIT validation evidence by 2026-08-21.
4. Tommy/Steve switch the single IconDB endpoint from Enovia SIT to Enovia QA after SIT validation passes.
5. The team confirms QA connectivity and begins FemCare QA testing.
6. The team retains the returned MAE identifier together with the source environment and test record.
7. Production restart remains gated by validation evidence, an agreed failure/rollback route, and a named decision owner.

## Confirmed Controls

- Cleanup clarification recorded 2026-08-13: retain a pre-clean inventory, clean all IconDB QA icons, and clean all IconDB-origin Enovia SIT records where feasible or at minimum the complete FemCare category/subsector population before the controlled FemCare test.
- Do not configure IconDB to send to Enovia SIT and QA simultaneously.
- A manual run or successful connection alone is not acceptance. Retain sample IDs, payload, result, MAE ID, routing outcome, and errors.
- Do not treat approximately 2026-08-25 or mid-September as committed dates until Jyoti provides the formal plan.
- Do not restart scaled OU production uploads until the QA gate and restart authority are confirmed.

## Actions And Owners

| Action | Owner | Target | Evidence / completion condition |
|---|---|---|---|
| Send correct FemCare JSON/request payload | Michal | 2026-08-12 | Jyoti confirms receipt of the exact SIT payload |
| Analyze payload and identify required Enovia corrections | Jyoti | 2026-08-14 | Field-level findings and September change scope |
| Retain representative validation and rollback/failure route | Michal / Tommy / Jyoti | 2026-08-13 | Sample ID, payload, approval/result, MAE ID, error route, rollback owner |
| Complete FemCare SIT validation | Michal / Tommy / Jyoti / FemCare | 2026-08-21 | Results retained against the agreed QA gate |
| Confirm exact migration dates and production-copy cutoff | Jyoti / Enovia team | 2026-08-21 | Written Enovia migration plan |
| Switch sole IconDB endpoint to Enovia QA | Tommy / Steve | Proposed 2026-08-24 | Configuration evidence and QA connectivity check |
| Start FemCare testing in Enovia QA | Michal / Jyoti / FemCare | Proposed 2026-08-25 | QA request/result and environment-linked MAE ID |
| Finalize repeatable migration/resynchronization procedure | Tommy / Steve / Jyoti / Michal | 2026-08-20 | Reviewed procedure with owners, rollback, and evidence |

## Delegation Message For Tommy And Jyoti

**Suggested subject:** IconDB coverage during my absence: SIT validation and QA endpoint switch

Hi Tommy and Jyoti,

During my absence next week, please use the following sequence as the operating control for IconDB:

1. Complete the FemCare SIT payload analysis and resolve or document any field-level issue.
2. Complete SIT validation by 21 August and retain the payload, sample identifier, result, returned MAE identifier, routing outcome, and any error evidence.
3. Do not point IconDB to SIT and QA at the same time.
4. After SIT validation passes, Tommy/Steve should switch the sole IconDB endpoint to Enovia QA and retain the configuration and connectivity evidence.
5. Begin FemCare QA testing only after the endpoint switch is confirmed.
6. If validation fails or an Enovia correction is required, Jyoti should document the exact field-level issue and whether it can enter the September change window. Do not proceed to the endpoint switch until the failure route is agreed.
7. Please record decisions and evidence in the shared project record. Escalate any date risk, ambiguous MAE/environment response, or pressure to run both endpoints to Tommy and me; involve Tripolina where an Enovia requirement or production-restart authority decision is needed.

The current Enovia SIT is planned for decommissioning on 31 August. The production-copy cutoff and replacement-SIT availability remain unconfirmed until Jyoti shares the formal plan.

Thank you,
Michal

## Draft Repeatable QA Resynchronization Process

This is the proposed control to finalize by 2026-08-20.

### 1. Confirm The Refresh

Jyoti/Enovia confirms in writing the source environment, target environment, production-copy cutoff, refresh start/end, expected downtime, scrub rules, and rollback contact. Freeze the dates as confirmed only after this notice.

### 2. Capture The Pre-Refresh Baseline

Export a controlled cross-reference of IconDB QA records and the current Enovia non-production records, including IconDB record ID, source environment, MAE identifier, version/status, and file presence. Retain counts and exceptions. Pause integration uploads before the agreed cutoff.

### 3. Isolate The Endpoint

Tommy/Steve confirms that IconDB targets only the intended Enovia environment. Record the endpoint configuration before any change. Do not enable SIT and QA in parallel.

### 4. Perform And Verify The Enovia Refresh

Enovia performs the production copy and scrub. Jyoti confirms completion and provides the actual cutoff. Verify that expected metadata and MAE identifiers exist and that files/images were removed as designed.

### 5. Reconcile Inventories

Compare the pre-refresh IconDB baseline with the refreshed Enovia metadata. Classify records as matched, missing in Enovia, missing in IconDB, identifier mismatch, version mismatch, or file missing by design. Stop if counts cannot be reconciled.

### 6. Select The Reload Mechanism

Tommy/Steve and Jyoti must test and approve one mechanism on a small representative sample:

- up-version and re-release from IconDB so Enovia receives the files while existing identifiers remain aligned; or
- controlled bulk upload where the refresh cannot be repaired by re-release.

For the current recovery, create the approved clean IconDB QA baseline before the FemCare SIT pilot, with retained before/after inventories and a reconstruction source. For future refreshes, do not wipe or bulk reload either system until the refresh scope, MAE behavior, identifier handling, duplicate behavior, and rollback have been reviewed.

### 7. Run The Pilot QA Gate

Use representative FemCare and cross-OU samples. Confirm Integration Type, Brand, Region routing, MAE generation/retention, intended copy list, file visibility, and usable error details. Link every returned MAE identifier to its environment.

### 8. Resynchronize In Controlled Batches

Process approved batches with before/after counts and an exception log. Reconcile each batch before starting the next. Quarantine failed or ambiguous records rather than retrying without diagnosis.

### 9. Sign Off Or Roll Back

Jyoti confirms Enovia results; Tommy/Steve confirms IconDB endpoint and record state; Michal or the named delegate confirms evidence completeness. If the gate fails, stop uploads, restore the prior endpoint configuration where appropriate, retain failure evidence, and invoke the named technical owner.

### 10. Close And Reuse

Record final counts, exceptions, decisions, timestamps, owners, and links to evidence. Update this procedure with the observed timings and failure modes before the next environment refresh.

## Power Automate Recurrence Resolution

**Current configuration update (2026-08-12):** Michal changed the Recurrence frequency from `Week` to `Day`. At 09:00 this should provide a daily trigger, but without an additional weekday condition it will also run on Saturday and Sunday.

### Recommendation

Keep **09:00 in `Central European Standard Time`** as the single morning snapshot time. Verify the next scheduled execution before treating the missed-run issue as fixed. If the requirement remains Monday-Friday, use a weekly recurrence with Monday-Friday selected, or add an explicit weekday guard to the daily trigger; otherwise the flow will run seven days a week.

### Corrective Steps

1. Open `IconDB Morning Snapshot` and inspect the Recurrence trigger definition, not only the flow's `On` status.
2. Confirm Frequency `Day`, Interval `1`, hour `9`, minute `0`, time zone `Central European Standard Time`, and concurrency `1`. If weekend runs are not wanted, revert to Frequency `Week` with Monday-Friday selected.
3. Check for a stale or future Start time and remove or correct it if it excludes 2026-08-13.
4. Save the flow and run Flow Checker; require zero errors and warnings.
5. Confirm the trigger is enabled and inspect run history after the next 09:00 scheduled occurrence. A manual test proves the actions, not the recurrence.
6. If no 2026-08-13 scheduled run appears, export or inspect the trigger definition and raise a Power Automate support case with flow ID `277e018f-85cd-4917-9ab4-94e2bffed162`, environment ID, expected time, time zone, last successful run, and missing-run date.
7. Completed 2026-08-12: `docs/power-automate-icondb-cps-refresh.md` now keeps the production snapshot at 09:00 and requires any future approved CPS refresh to run afterward.

Until the next scheduled run succeeds, continue to mark current-day mail/calendar coverage unavailable rather than reusing the prior snapshot.
