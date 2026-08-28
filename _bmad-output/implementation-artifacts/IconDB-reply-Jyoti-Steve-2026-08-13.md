# Draft Reply To Jyoti And Steve - 2026-08-13

> **Superseded:** This SIT-first draft was sent before Jyoti's 11:20 reply. Do not reuse it as the operating plan. The current QA-first team response is in `IconDB-team-reply-QA-first-FemCare-plan-2026-08-13.md`, and the authoritative dates are in the SharePoint `Project schedule` master.

**Suggested subject:** Action required: IconDB clean-state plan and FemCare SIT validation

**Suggested To:** Jyoti, Steve, Tommy, Lauren, Aleksandra Danilecka (Ola)
**Suggested Cc:** None initially; add only a confirmed Enovia refresh or OU sign-off owner if needed

Team,

**Context for leadership:** IconDB is technically live, but the current MAE mismatch and legacy test data require a controlled reset and FemCare SIT sign-off before we switch to Enovia QA and resume production scale-up.

To keep the FemCare SIT validation on track next week, I need your help with the actions below. Please confirm the plan, owners, and any constraints by **Friday, 14 August**.

| Action / decision needed | Owner | Due | Completion evidence |
|---|---|---|---|
| Update Enovia to accept `copyIntegrationType` as one string in SIT and production, then report deployment timing | Jyoti | 14 Aug | Deployment evidence and environments ready for validation |
| Confirm the canonical mapping for `EECAR`, `Europe`, and `Europe Enterprise` | Lauren / Jyoti | 14 Aug | One agreed value map for the test set |
| Review the revised FemCare sequence and advise whether SIT validation first, followed by QA access/testing, works for the FemCare team | Ola | 14 Aug | Confirmation that the sequence works for FemCare, or specific timing/access concerns |
| Confirm whether Enovia SIT can delete all IconDB-origin records; if not, confirm deletion of the full FemCare category/subsector population | Jyoti | 14 Aug | Agreed deletion scope, owner, and execution timing |
| Prepare the IconDB QA inventory/export, deletion, reconstruction source, and payload support | Steve / Tommy | 14 Aug | Executable cleanup plan and retained reconstruction source |
| Retain the pre-clean inventories, complete the agreed IconDB QA / Enovia SIT cleanup, and verify the result | Michal / Steve / Tommy / Jyoti | 17 Aug | Before/after files and reconciled counts confirmed by the PO and developers |
| Execute the controlled FemCare SIT test and obtain FemCare business sign-off | Michal, supported by Ola / FemCare / Jyoti / Steve / Tommy | 18-21 Aug | Test evidence and written FemCare sign-off |
| Confirm the Enovia refresh scope, cutoff, MAE behavior, and schedule | Jyoti | 20 Aug | Written refresh plan and answers to the questions below |
| Switch the sole IconDB endpoint from SIT to QA after SIT sign-off | Steve | Proposed 24 Aug | Configuration evidence and QA connectivity result |

I confirm that `copyIntegrationType` will contain one business value for each icon. Under the current business process, there is no reason for one icon to have two integration types. If two integration types or GS1 subcopy types are required, they must be represented by separate icon records, each with its own MAE/canonical identifier.

Jyoti, please update Enovia to accept `copyIntegrationType` as a single string consistently across all environments, especially SIT and production, and let the team know when each environment is deployed and ready for validation. Steve, please keep the IconDB payload contract consistent with that definition.

Thank you both for prioritizing this. We are close to completing the technical validation needed for production scale-up.

We need a controlled clean state before the next validation. The current environments contain legacy and test records with unclear ownership and lifetime, and the seven icons released in IconDB production produced only one returned MAE number. This prevents reliable reconciliation between IconDB and Enovia and would make FemCare sign-off ambiguous.

Before any deletion, please export and retain the affected IconDB and Enovia record IDs, MAE IDs, categories/subsectors, creation dates, statuses, and current counts. We also need named execution owners, confirmation of the exact deletion scope on both sides, and a rollback or reconstruction source.

Proposed sequence:

### 1. Prepare FemCare SIT Validation

1. Delete all existing icons from IconDB QA after the pre-clean inventory is retained.
2. In Enovia SIT, delete all IconDB-origin icons if Jyoti confirms the batch is operationally manageable. If the full batch is too large, delete at minimum every IconDB-origin record connected to the FemCare category/subsector.
3. Reconcile the post-clean counts and confirm that no FemCare records remain in either test population.
4. Upload a new controlled FemCare sample from IconDB QA to the currently connected Enovia SIT.
5. Retain the request payload, IconDB record ID, returned MAE ID, Enovia destination/copy list, region and integration-type interpretation, result, and any error details for every sample.
6. Obtain written FemCare sign-off in Enovia SIT before changing the endpoint.

### 2. Switch To Enovia QA And Rebuild QA

1. After FemCare SIT sign-off, Tommy/Steve switch the sole IconDB non-production endpoint from Enovia SIT to Enovia QA. SIT and QA must never be active targets at the same time.
2. Complete the agreed clean-state preparation in both IconDB QA and Enovia QA, with before/after inventories and counts.
3. Re-upload the approved FemCare records and then run controlled individual EU tests before the broader QA bulk upload.
4. Reconcile every returned MAE ID and confirm Integration Type, Brand, Region, destination/copy list, file visibility, and error handling before QA sign-off.

### 3. Reset And Rebuild Production

1. Record the seven current IconDB production records and their Enovia counterparts, including the single MAE number returned so far.
2. After the QA gate passes and the accountable owners approve the reset, delete those IconDB-origin records from both IconDB production and Enovia production.
3. Reconcile both production systems to the agreed zero/clean baseline.
4. Upload controlled individual records first, then the approved OU batches. Retain one traceable creation and integration history for each rebuilt record.

One additional point from Lauren: Canvas/IconDB now uses the new EECAR region and existing `Europe Focus` values have been changed to `Europe`. Existing QA records updated automatically inside Canvas/IconDB, but that metadata change did not trigger a new send to Enovia.

The clean-state upload should therefore create the new integration events; Lauren's separate resend script should not be needed for records that we delete and recreate. Please confirm the canonical mapping for `EECAR`, `Europe`, and `Europe Enterprise` before we build the test set.

There is also a recurring environment-refresh dependency to resolve. Enovia non-production environments are periodically replaced from a scrubbed production copy; the first known refresh is planned for 31 August. Jyoti, please confirm:

- which Enovia environments will be refreshed and the expected frequency;
- whether production MAE IDs and all matching metadata are copied into Enovia QA/SIT;
- the exact production-copy cutoff and refresh dates; and
- whether a production copy into IconDB QA would preserve alignment, or whether we need a repeatable IconDB-to-Enovia resynchronization job.

IconDB needs advance notice of every refresh so uploads can be paused, inventories captured, endpoints controlled, and post-refresh reconciliation completed.

Any production icons created or changed after the Enovia production-copy cutoff will be absent or stale in the refreshed non-production environment. We therefore need a dated delta manifest and an agreed replay/reconciliation step for all records changed between the cutoff and refresh completion.

Our target by 1 September is production sign-off for the seven Fabric Care North America icons plus the approved FemCare, Oral Care, and Fabric Care Europe populations. The minimum acceptable outcome is production readiness/sign-off for the seven Fabric Care North America icons and FemCare. Any outcome between those two gates will be reported against the completed OU sign-offs and reconciled icon counts.

Best regards,

Michal

## Internal Review Notes - Do Not Send

### Recipient Recommendation

- **To:** Jyoti, Steve, Tommy, Lauren, and Ola. Each has a direct action or decision in this message.
- **Bernard:** Do not include on the detailed technical thread. Send him the short sponsor update after the 14 August confirmations or immediately if the minimum 1 September outcome becomes at risk.
- **Rachel, Emilian, Noelle, and Jaimie:** Do not include. They are in the AAC stream, which is outside this FemCare and environment-cleanup decision.
- **Zoya:** Keep off the initial thread. As Global AW Copy Process Leader, add her only if the technical owners cannot resolve the required region/copy-list behavior or if the plan needs a global copy-process decision.
- Keep the operational thread small enough that silence has a clear meaning and every recipient knows what response is expected.

- Lauren's update changes the stored region value in Canvas/IconDB. It does not replay the integration event, so Enovia keeps its previous value until the icon is newly released or a resend/backfill script is run.
- Her comment about running the script "only on QA" most likely means selecting QA IconDB records and sending them to the currently connected Enovia test environment. The clean-state plan makes this unnecessary for deleted/recreated records, but the exact source and target still need confirmation if it is used for any retained record.
- No production icons were affected by the region rename because Lauren found only North America records in production.
- The label `EECAR` should be confirmed with Lauren/Jyoti before the test. Do not silently equate it with `Europe Enterprise` unless the canonical region mapping says they are the same value.
- The cleanup is justified by the existing MAE mismatch, legacy/test records, unclear provenance, and the need for an unambiguous FemCare sign-off. It remains a controlled data operation: inventory, scope, owners, reconstruction source, before/after counts, and written gate approval are required.
