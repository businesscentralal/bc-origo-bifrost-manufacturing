# Reverse posted production entries (#25)

Gunnar approved two separate whole-entry operations on 23 November 2026. No partial quantity parameter is accepted.

| Criterion | State | Implementation | Verification |
| --- | --- | --- | --- |
| AC01 | Implemented | Native output correction, including last-operation capacity; remaining quantities and original/correcting entry identities returned. Intermediate capacity can be selected alone. | 97653: output ten in 1033/1039, intermediate capacity, atomic batch rollback; bilingual self-seeded MCP. |
| AC02 | Implemented | Native item tracking and application are carried into consumption correction. Repeated consumption correction is refused using its item application. | 97653: lot-tracked consumption returns fifty to the same lot; original quantity retained; repeated reversal refused. |
| AC03 | Implemented | Mandatory exact selected-entry count, including explicitly selected capacity only. | 97653: missing/mismatched counts for both operations create no entries; bilingual MCP. |
| AC04 | Implemented | Typed lists, matching order/type, Released state, no repeated correction; native posting restrictions preserved. | 97653: foreign order, wrong type, Finished order, duplicates, subcontracting, last-operation capacity and rollback. |
| AC05 | Implemented | Existing Manufacturing write and posting gates, including discovery. | 97654: Read, Full without posting, no Manufacturing permission, and Read with posting; both operations denied and logged. |
| C1 | Implemented | Foundation error response and nextStep; native failure text retained as PreconditionFailed. Entire selection is one transaction. | 97653/97654: all named error codes, persisted Foundation error checks and unchanged entry counts; Omit Commit refusal. |
| C2 | Implemented | Twelve public English help chapters, Icelandic discovery/refusals, synchronized is-IS XLF; no en-US XLF. | Source guards and full help readback in 1033/1039 through the MCP help tool. |
| C3 | Implemented | All new business fixtures are created from raw owned records and removed by prefix. | Assigned W1/IS tenants only; exact-head AL/MCP receipts and cleanup counts in PR Current state. |
| C4 | Already present | No product page or action changes. | No UI clips required by the story. |

The native reversal APIs are present in the BC 28.5 symbols. The application and Foundation floors remain unchanged. BC 28.5 has no `SetHideDialog` procedure; API sessions take the native non-GUI confirmation path. GUI AL tests answer the native confirmation and success message with handlers. The native API posts the original dates, dimensions, item tracking and applications. The originals' posted quantities remain unchanged; normal posting updates application and reversal state.

The complete selection is checked again under locks. A commit-error scope protects native correction posting inside the `Codeunit.Run` transaction. A test-only, manually bound native-event fault proves that a failure after actual correction posting rolls back the item and capacity corrections. No product operation deletes ledger entries. Test-only fixture cleanup removes only owned prefixes.

The full suite is the paired CI run at the PR head. Licence-path checks are NOT_RUN per the release policy. Current counts, full SHA, run URL, environment restoration and review status belong in the PR's single Current state comment.
