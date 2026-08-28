title: 'Persist Portfolio Incremental Comparison State'
type: 'feature'
created: '2026-08-26'
status: 'complete'
baseline_commit: '21b81a286f38c1596127084d07ec87e20fa0cc4f'
context:
  - 'docs/power-automate-icondb-control.md'
  - 'schemas/portfolio-evidence-delta.schema.json'

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The disabled `Portfolio Evidence Delta` flow has a verified run ID and watermark contract, but no persisted conversation-head or calendar-fingerprint state. Without that state, overlap collection cannot reliably distinguish a new item from an advanced old thread or a changed recurring meeting.

**Approach:** Define one authoritative, privacy-minimized `latest-state.json` containing the successful checkpoint plus current thread heads and calendar fingerprints. Extend delta calendar changes with deterministic fingerprints, validate continuity against the prior state, and atomically promote the complete next generation only after all delta and state checks pass.

## Boundaries & Constraints

**Always:** Keep the production `IconDB Morning Snapshot` unchanged and the prototype off; key thread state by non-empty Outlook conversation ID and `mail:` head ID; key calendar state by `event:` stable ID and a `sha256:` fingerprint of the canonical privacy-minimized event representation; exclude subject/body from `busyOnly` fingerprint input; require the state run ID and watermark to equal the promoted delta; preserve the previous valid state on every failure; use one authoritative state file so checkpoint and comparison state cannot diverge.

**Ask First:** Enabling or scheduling the prototype; changing mailbox, calendar, horizon, routing, retention, or privacy scope; deleting historical state rather than retaining a cancellation marker; modifying the production flow.

**Never:** Hash the raw connector event payload; persist sender, recipients, attendees, location, message body, private event details, or attachment metadata in state; infer an advanced thread from subject; promote state from an incomplete or stale delta; maintain independently authoritative checkpoint and state files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| First state promotion | Valid delta plus validated bootstrap checkpoint | Create `latest-state.json` with matching run/checkpoint, thread heads, and changed-event fingerprints | Reject if bootstrap run or watermark differs |
| Advanced thread | Prior head `mail:1`; delta says `previousHeadId=mail:1`, `currentHeadId=mail:2` | Replace only that conversation head with `mail:2` | Reject missing/mismatched previous head |
| Calendar update | Existing event ID with a new canonical fingerprint | Replace fingerprint and mark `updated` | Reject malformed hash or privacy-incompatible fields |
| Cancelled event | Existing event marked cancelled | Retain ID, fingerprint, and cancellation marker | Never silently delete it |
| Replay or split generation | Delta predecessor/run/watermark differs from state | Preserve prior `latest-state.json` byte-for-byte | Exit nonzero; leave no `.promoting` file |

</frozen-after-approval>

## Code Map

- `schemas/portfolio-evidence-delta.schema.json` -- require a canonical SHA-256 fingerprint on each calendar change.
- `schemas/portfolio-control-state.schema.json` -- define the combined checkpoint, thread-head, and calendar-fingerprint state contract.
- `scripts/Test-PortfolioEvidenceDelta.ps1` -- validate fingerprints and optionally invoke state promotion after delta validation.
- `scripts/Promote-PortfolioControlState.ps1` -- merge a valid delta into prior state/bootstrap and atomically replace `latest-state.json`.
- `scripts/Test-PortfolioControlState.ps1` -- fail-closed structural, continuity, uniqueness, and privacy validation.
- `docs/power-automate-icondb-control.md` -- map the state contract to the disabled flow and document bootstrap/migration behavior.

## Tasks & Acceptance

**Execution:**
- [x] `schemas/portfolio-evidence-delta.schema.json` -- require a privacy-safe fingerprint on each calendar change.
- [x] `schemas/portfolio-control-state.schema.json` -- define the authoritative checkpoint, thread-head, and calendar-fingerprint state structure.
- [x] `scripts/Test-PortfolioControlState.ps1` -- validate allowed fields, unique keys, hash format, timestamps, run/checkpoint consistency, and cancellation retention.
- [x] `scripts/Promote-PortfolioControlState.ps1` -- verify predecessor continuity, merge thread/calendar changes, validate the candidate state, and atomically promote it.
- [x] `scripts/Test-PortfolioEvidenceDelta.ps1` -- require privacy-safe fingerprints and expose an explicit state-promotion option without weakening existing validation.
- [x] `scripts/Test-PortfolioControlStateIntegration.ps1` -- cover bootstrap, replay, new/advanced threads, updated/cancelled events, duplicate keys, malformed hashes, failed promotion, and next-run reuse.
- [x] `docs/power-automate-icondb-control.md` -- record exact Power Automate fields and keep activation gated.

**Acceptance Criteria:**
- Given a validated predecessor and delta, when state promotion succeeds, then one `latest-state.json` atomically advances both run checkpoint and comparison state and is accepted as the next predecessor.
- Given any continuity, privacy, fingerprint, duplicate-key, or write failure, when promotion is attempted, then the prior state remains unchanged and no temporary file remains.
- Given the completed local contract, when tenant work resumes, then the prototype remains off until its emitted delta and state transition pass all synthetic tests.

## Spec Change Log

- 2026-08-27: Completed adversarial remediation: canonical fingerprint recomputation, deterministic thread comparison, strict JSON booleans, no-op transition rejection, serialized promotion, validation/read mutation detection, and focused integration regressions. Local acceptance passed; tenant activation remains gated.

## Design Notes

`latest-state.json` is the authoritative predecessor after bootstrap and retains the existing `run` and `checkpoint` shapes, allowing the delta validator to consume it through `-PreviousCheckpointPath`. The older `latest-checkpoint.json` remains bootstrap evidence only and is not independently advanced. Fingerprints use lowercase `sha256:` plus 64 hexadecimal characters over a documented canonical representation; matching uses IDs and hashes, never subjects.

## Verification

**Commands:**
- `powershell -NoProfile -File scripts/Test-PortfolioControlState.ps1 -Path <state>` -- expected: valid state accepted with thread/event counts.
- `powershell -NoProfile -File scripts/Promote-PortfolioControlState.ps1 -DeltaPath <delta> -PreviousStatePath <state-or-bootstrap> -PromoteToState <latest-state.json>` -- expected: atomic promotion and next-run reuse.
- Focused PowerShell fixture suite -- expected: positive transitions pass; replay, mismatch, privacy, duplicate, malformed-hash, and interrupted-write cases fail closed.
