# IconDB Update To Bernard - 2026-08-12

**Suggested subject:** IconDB update: production route validated; scale-up plan revised

Hi Bernard,

A short update against the recovery plan I shared previously.

**Top line:** The mapping and integration-type corrections enabled a successful end-to-end production test. An icon passed approval and was confirmed in production Enovia. IconDB is live and the production route works, but scaled OU uploads remain paused until the non-production validation gate is completed.

**Main bottleneck:** Enovia confirmed that the required single-string change reaches QA on 31 August and production on 11 September. EECAR is not in scope and its feasibility will not be known until 24 August. The current SIT is refreshed on 31 August, so formal SIT sign-off would not close the QA, region-mapping, or production gates.

**Environment clarification:** Ruby Yu's official plan confirms that SIT is unavailable from 31 August until 14 September and that 2022x testing should use QA during this period. The 28 August production database copy is for the replacement SIT only; QA refresh/no-refresh and its effective baseline remain to be confirmed before endpoint switch or testing.

**Change versus the previous plan:** We have dropped formal SIT sign-off from the critical path and moved to a QA-first plan. No destructive action will occur during next week's coverage gap. Tomita returns Tuesday and will coordinate sample/readiness confirmation while the team prepares inventory, rollback, and reconstruction evidence.

**Revised plan:**

- confirm the FemCare sample, expected values, signer, and EECAR handling by 24 August;
- complete the QA clean-state and resynchronization package by 27 August;
- verify the QA deployment and baseline, reconcile it with IconDB QA, and switch the sole endpoint on or after 1 September only if ready;
- complete controlled FemCare QA validation on 2-7 September if the baseline gate closes; and
- validate production only after the 11 September deployment, QA evidence, a post-deployment production test, rollback handling, and accountable restart decision;
- upload production icons with final IconDB names/IDs, then replace Graphics Library references in Rule Manager before Emilian's AAC team runs E2E validation.

The former 1 September production-sign-off target is no longer credible. The earliest planned business-day production test is Monday, 14 September, subject to confirmation of the 11 September deployment and team availability; go-live follows only after the test and approval. This also delays AAC because its rules must move from Graphics Library icon references to the final production IconDB names and IDs before AAC validation can complete.

I will escalate if EECAR treatment, FemCare sign-off ownership, QA deployment evidence, or restart authority remain unresolved by their gates.

Best regards,
Michal
