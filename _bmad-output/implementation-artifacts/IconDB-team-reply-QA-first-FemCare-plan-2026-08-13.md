# Draft Team Reply - QA-First FemCare And AAC Plan

**Suggested subject:** IconDB revised activation plan: QA validation, production dependency, and AAC impact

**To:** Jyoti, Steve, Tommy, Lauren, Aleksandra (Ola), Jakub, Fady, Simge, Bernard, Emilian
**Cc:** Tripolina, Noelle

Hi Team,

I rebuilt the plan based on all information gathered today.

## Help needed

Please confirm the QA readiness plan, owners, and any constraints by **Monday, 17 August**. Friday, 14 August is a day off in lieu of the bank holiday.

We need written confirmation of the Enovia QA baseline before changing the IconDB endpoint or starting FemCare testing.

- **Jyoti / Enovia team:** confirm the 31 August QA deployment and whether QA is refreshed or retains its current baseline. Confirm readiness for the documented 11 September production deployment.
- **Ola / Jakub / Fady / Simge / FemCare:** select one to three samples, expected results, and the business signer.
- **Lauren / Jyoti:** confirm the supported EECAR treatment or exclude EECAR from the first gate.
- **Tommy / Steve:** prepare inventory, rollback, reconciliation, and the controlled endpoint switch.
- **Emilian / AAC team:** confirm the AAC validation owner and readiness sequence after the production icons and Rule Manager references are available.

## Short LT note

Based on the confirmed environment dates and the remaining EECAR gap, I propose that we remove formal FemCare SIT sign-off from the critical path and run the controlled business validation in Enovia QA only after the 31 August deployment and the QA environment baseline are confirmed.

The reasons are:

- `copyIntegrationType` is available in SIT on 19 August, QA on 31 August, and production on 11 September;
- EECAR is not in the September change scope, and feasibility will not be confirmed until 24 August;
- full IconDB-origin cleanup in SIT is not feasible;
- SIT is refreshed on 31 August from the 28 August production copy and returns on 14 September;
- Jyoti confirmed that there is no official QA refresh plan shared yet, so we must not assume that the production copy will also be loaded into QA; and
- I am out next week, while Tommy returns on Tuesday, which leaves too little controlled time for cleanup, execution, business sign-off, and evidence before the refresh.

A SIT test would therefore not close the QA, EECAR, or production gates. Our operating plan is QA-first.

The production-copy dependency must be treated precisely: the 28 August copy is confirmed for the replacement SIT only. Before any QA test, Jyoti must confirm in writing whether Enovia QA will also be refreshed or copied from production, when that will happen, the effective production-data cutoff, what metadata/files will be scrubbed, and when QA is stable for testing. If no QA refresh is planned, she must confirm the current QA baseline and that it is safe to use after the 31 August deployment.

Production go-live cannot occur when the correction is deployed. The team still needs to verify the deployment, run a controlled production test, reconcile the result, confirm rollback/failure handling, and obtain written restart approval.

This also delays AAC activation. AAC depends on production icons being uploaded with their final IconDB naming and IDs. Rule Manager must then replace the remaining Graphics Library references with those IconDB names and IDs before AAC can complete end-to-end validation and go live.

## Coverage Next Week

I am out from Monday, 17 August, through Friday, 21 August. Tommy returns on Tuesday, 18 August, and should coordinate the readiness actions below with Steve and Jyoti.

On Monday, please do not delete records, upload test icons, change the IconDB endpoint, or perform any production action. Monday is a response and coordination point until Tommy is back on Tuesday.

From Tuesday, preparation may continue, but no destructive action or test execution should occur until the sample, expected values, rollback evidence, and owners are confirmed.

## Actions Before QA Deployment

| Action | Owner | Due | Completion evidence |
|---|---|---|---|
| Confirm one to three representative FemCare icons for the QA gate | Ola / Jakub / Fady / Simge / FemCare | 24 Aug | Icon IDs or files, category/subsector, and named business signer |
| Record the expected result for each sample | FemCare, supported by Lauren | 24 Aug | Expected Integration Type, Brand, Region, Enovia destination/copy list, and approval result |
| Confirm EECAR handling | Lauren / Jyoti | 24 Aug | Supported mapping for QA, or written agreement to exclude EECAR records from the first gate |
| Prepare IconDB QA inventory, reconstruction source, and rollback package | Steve / Tommy | 27 Aug | Before-state IDs, MAE IDs, counts, statuses, files/source data, and rollback steps |
| Confirm Enovia QA refresh status and target-side baseline | Jyoti | Before endpoint switch, target 31 Aug | Written confirmation whether QA will receive a production copy; if yes, refresh date, cutoff, scrub scope, and availability; if no, current baseline and readiness confirmation |
| Confirm the sole IconDB endpoint switch plan | Tommy / Steve | 31 Aug | Current endpoint evidence, approved QA target, connectivity check, and rollback owner |
| Confirm production deployment readiness | Jyoti / Enovia team | Before 11 Sep | Written confirmation that the Integration Type correction is ready for the 11 Sep production deployment |
| Prepare post-production validation and AAC dependencies | Tommy / Steve / Emilian | Before production deployment | Production sample/sign-off plan, IconDB name/ID list, Rule Manager update owner, and AAC test sequence |

FemCare does not need to perform an upload next week. FemCare's required preparation is to select the samples, state the expected business outcome for each field, name the signer, and reserve availability for the QA test window.

## QA Execution

1. On or before 1 September, Jyoti confirms that the Enovia changes are deployed in QA and confirms the actual QA baseline: whether a production copy/refresh occurred, its cutoff and scrub scope, or that no QA refresh is planned and the existing baseline is stable.
2. Tommy and Steve reconcile the confirmed Enovia QA baseline against the IconDB QA inventory, close any mismatch or reconstruction action, confirm the readiness package, and then switch the sole IconDB non-production endpoint to Enovia QA. SIT and QA must not be active targets at the same time.
3. From 2 September, upload and approve one FemCare sample in IconDB QA.
4. Retain the IconDB ID, request payload, returned MAE ID, target environment, Integration Type, Brand, Region, destination/copy list, image/file visibility, status, and any error details.
5. Jyoti confirms the Enovia result and FemCare confirms whether the observed result matches the expected business outcome.
6. Only after the first sample is reconciled should the team process the remaining approved samples.
7. Complete written FemCare sign-off by 7 September, or record the exact failed field, technical owner, correction route, and revised date.
8. After the production correction is deployed on 11 September, execute a controlled production sample and retain the same evidence. The earliest planned business-day test is Monday, 14 September, subject to deployment confirmation and team availability.
9. Go live or restart scaled production uploads only after the production result is reconciled, rollback/failure handling is confirmed, and the accountable owner approves the restart.
10. Upload the required production icon population with final IconDB names and IDs, then update Rule Manager rules from Graphics Library references to the corresponding IconDB names and IDs.
11. Emilian's AAC team completes AAC end-to-end validation against the updated Rule Manager references before AAC go-live.

Do not run a bulk upload as the first QA test. Do not delete or reset production records as part of this QA activity.

If the QA refresh or baseline remains unconfirmed, or if the refreshed metadata cannot be reconciled with IconDB QA, do not switch the endpoint and do not start the FemCare test. Record the blocking mismatch, owner, and revised readiness date.

## Optional SIT Smoke Test

The default is not to run SIT. If Tommy, Steve, and Jyoti believe a SIT smoke test still provides specific technical value, please agree the objective in writing on 18 August. It must be limited to one non-EECAR FemCare record, use only the minimum agreed cleanup, retain full evidence, and remain non-gating. It must not be presented as FemCare sign-off or as evidence that QA is ready.

## Production Gate

The previous 1 September production-sign-off target is no longer achievable. The Integration Type fix reaches production on 11 September. This is the earliest technical prerequisite, not a go-live date. Production validation and any scaled OU restart can occur only after:

- the 11 September production deployment is confirmed;
- the FemCare QA gate passes;
- a controlled production test passes after deployment;
- rollback and failure handling are retained; and
- the accountable restart owner gives written approval.

## AAC Gate And Bernard Commitment

The 7 August Technical Activation update committed to correct production routing before scaled uploads and responded to Bernard's question about AAC readiness. Bernard confirmed that Emilian now leads the AAC work, so Bernard, Emilian, and Noelle are included in this update.

AAC cannot go live independently of the IconDB recovery. The required sequence is:

1. deploy and validate the Enovia production correction;
2. upload the required production icons with stable IconDB names and IDs;
3. update Rule Manager rules that still reference Graphics Library icons so they reference the corresponding IconDB names and IDs; and
4. complete AAC end-to-end validation under Emilian's ownership.

The earlier commitment to mass-upload FC NA, FC EU, Fem EU, and Oral EU on 14-15 August is therefore superseded by the Enovia environment change and production-fix schedule. This dependency was not visible when the earlier activation timing was communicated.

Please reply only with corrections, unavailable owners, or constraints against this sequence by **Monday, 17 August**. If there are no objections, Tommy can use this as the operating plan from Tuesday.

Best regards,

Michal
