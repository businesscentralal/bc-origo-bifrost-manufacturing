# Changelog


## Unreleased

- #42 (first AppSource release prep): classify `Manufacturing.ProductionOrder.ChangeStatus` and `Manufacturing.ProductionOrder.CreateFromDemand` as `write` (no confirmation preview; `expectedCount` accepted and ignored); `Finish` stays irreversible. Raise the Foundation dependency to 28.0.16.1, remove the loose `docs/issue-25/26` acceptance files. No new objects; is-IS selection text updated.

- Issue #25: `Manufacturing.Output.Reverse` and `Manufacturing.Consumption.Reverse` post whole-entry corrections with mandatory exact-count confirmation, posting permission, atomic rollback, original tracking and bilingual refusal guidance. App objects 10077107–10077112; test objects 97653–97657.


- #23: `Manufacturing.ProductionOrder.CreateFromDemand` creates production orders for the lines of a released sales order with Business Central's standard create-from-sales routine (no dialog): `ItemOrder` makes one order per sales line, `ProjectOrder` one order for the whole sales order (source type Sales Header); every new order line is reserved or tracked against its sales line. Status Planned, FirmPlanned (default) or Released (Released also needs `BIFROST MfgPost ori`). Irreversible: confirmed by `expectedCount` (number of orders). Lines that are not production-replenished items, already reserved, blocked, without a shipment date, or with an uncertified BOM or routing come back in `skipped[]` with a reason and `nextStep`. Sales demand only; project demand is not part of this type. App codeunits 10077082-10077084, 10077099-10077100 (enum value 10077082); test codeunits 97641, 97643, 97644, 97652 and own-tenant MCP fixture table 97646 (insert seeds an owned released sales order, delete removes it and everything the call created). The #37 effect test now lists CreateFromDemand as the one non-posting irreversible type.
- Merge repair: move `Mfg Demand Fixture Tests ori` from codeunit 97649 to the next unallocated test object ID, 97652, retaining main's `Mfg WhereUsed Tests ori` at 97649. Test behaviour and assertions are unchanged.
- Issue #29: `Manufacturing.WhereUsed.Get` uses native date-effective, multilevel calculations with owning BOMs, traversal levels and required quantities. Objects 10077102–10077104; tests and owned MCP fixtures 97649–97651. Also add `Manufacturing.ProductionBOM.ExchangeItem` (10077101, 10077105–10077106; tests 97646), creating new versions only through the native processing-only report, with confirmed version counts and atomic certification rollback. Existing headers, versions and lines are preserved. English help and Icelandic discovery/refusals are synchronized.

- #37: classify `Manufacturing.ProductionOrder.Reopen` as `write`, with no irreversible confirmation preview. Accept and ignore legacy `expectedCount`; retain the once-only, output, valuation and permission checks. ChangeStatus, Finish and ProductionJournal.Post remain irreversible because they can post. Update English/Icelandic selection help and contract chapters. Regression coverage checks every Manufacturing type and reopening with confirmation enabled and missing or mismatched counts. No new object IDs.

- #22: `Manufacturing.ProductionOrder.Reopen` reopens a finished production order once through the standard Business Central status move, with posting permission, `expectedCount` confirmation, output and valuation-date checks. BC 28.5 uses the native public wrapper with a manually scoped document subscriber; API calls use its default confirmation after the expectedCount gate. New app codeunits 10077068–10077069, 10077077 and 10077081; test objects 97635–97639. Generic status-field write hints name Reopen. The owned Reopen and read fixtures use the supported Pick + Manual flushing option on their locations without pick requirements (97630, 97637).

- Copy a production BOM or a routing into a new Under Development version on the same record through `Manufacturing.ProductionBOM.CopyVersion` and `Manufacturing.Routing.CopyVersion` (#28). The call creates an empty version first and then copies, and it refuses a target that already exists so no existing line is removed. Send no or systemId, startingDate, and optionally sourceVersionCode, targetVersionCode and description. A blank target takes the next code from Version Nos. The answer returns versionCode, recordStatus UnderDevelopment, startingDate, lineCount and, for a routing, the tool, personnel, quality-measure and comment counts, then names the matching SetStatus call. App objects 10077094–10077098 (enum values on 10077085); test objects 97671 and 97672.
- Issue #26: add `Manufacturing.ComponentAvailability.Get` and
  `Manufacturing.ProductionOrderStatistics.Get` with reservation-aware shortage
  quantities, native LCY costing, strict identity/status validation, the Manufacturing
  read-role boundary and English help with Icelandic discovery/refusals.
  Added app codeunits 10077048–10077049 and 10077065–10077067, enum extension
  10077064; test codeunits 97628, 97630–97631 and 97634, test permission set 97632,
  and staged MCP fixture table 97633 (owned posting data and cleanup).
  Correct the object ledger entries for existing tests 97618, 97619, 97648 and 97669.

- Add the end-to-end certification loop (#8 AC13): a Planned order whose BOM and routing are Under Development is refused by Refresh, both SetStatus types certify them, and Refresh then succeeds, in 1033 and 1039, plus a routing-only edge case (97680).
- Recognize BC 29's "You must specify No." certification error so a blank production BOM component keeps the session-language explanation, including Icelandic MCP calls (#6; 10077086). Cover both languages, unchanged status and cleared certification context in native tests (97660).

- Explain known production BOM and routing certification failures in the session language in front of the platform error (10077086). The Microsoft sentence is kept. Icelandic callers still see hringvísun, ekki til lengur, stöðvunarferla, ræsiferla, raðaðar and Nr. when the platform text stays English (97660, 97661, 97665).

- Measure production-journal preview sequence numbers before Post in the G/L cost-posting fixture, so the Item Ledger and G/L sequence assertions still prove PreviewPost consumed nothing (#6; 97648). Post still runs with the same flags, and the entryCount and glEntryCount assertions stay.

- On BC 29, grant the native `D365 ITEM, EDIT` and `D365 WHSE, VIEW` roles in the production-order permission baseline so Create can read Stockkeeping Unit and Refresh can read Warehouse Request, and make the journal preview fixture post to G/L on a company whose automatic and expected cost-posting flags are off, restoring those flags afterwards (#6; 97608, 97648). Assertions are unchanged.

- Match the production-order status/finish catalogue test to the session language, retaining exact English and Icelandic description assertions in LCIDs 1033 and 1039 (#6; 97626).

- Validate production-journal `finished` as a JSON boolean independently of the session language (#7, PR #18; 10077080). Add bilingual true/false preview and confirmation checks plus structured rejection of non-boolean values without posting (97648).

- Invoke the owned production-order fixture codeunit explicitly from the source-table-free test fixture page (97667), so authenticated UI verification creates its own data rather than relying on a RunObject action with no current record.

- Preserve ledger sequence numbers in production-journal PreviewPost (#7, PR #18): build and post inside the standard Business Central preview boundary, enable Item Jnl.-Post preview mode, and serialize captured entries through Foundation’s public preview helper (10077073/10077075). Extend native AC13 parity coverage with unchanged Item Ledger and G/L sequence assertions (97648).

- Production journal through `Manufacturing.ProductionJournal.Get`, `.PreviewPost` and `.Post` (#7). Lines are built by Business Central's own `Production Journal Mgt` (flushing, routing links, picks, blocked items) inside a `Codeunit.Run` boundary; Get and PreviewPost always roll back, Post commits through `Item Jnl.-Post Batch` and is irreversible: it needs Foundation's `expectedCount` (counter `Prod Jnl Confirm ori`) and `BIFROST MfgPost ori`. Request `lines` post exactly what is listed; line errors are collected with their index. Get/PreviewPost are listed to callers who can write `Item Journal Line`. `Data.Records.Set` on `Item Journal Line` stays unrestricted (documented in the Post notes). App objects 10077070–10077080; test objects 97640, 97642, 97645, 97647.

- Production order status change, finish and finish check through `Manufacturing.ProductionOrder.ChangeStatus`, `Manufacturing.ProductionOrder.Finish` and `Manufacturing.ProductionOrder.CheckFinish` (#6). ChangeStatus and Finish are irreversible: they run the standard `Prod. Order Status Management` change, which commits, and need Foundation's `expectedCount` confirmation (`Confirm Gate ori`, counter `Prod Order Confirm ori`) and the new assignable posting token `BIFROST MfgPost ori` (not part of Full or Read; they are hidden without it). Finish refuses missing output or consumption unless acknowledged (`acceptMissingOutput`, `acceptMissingConsumption`), consumption without output unless `finishWithoutOutput`, and outstanding subcontract purchase orders or picks; CheckFinish reports the same findings and changes nothing. `Data.Records.Set` of Production Order Status, Finished Date and Reopened is refused with a hint. Foundation dependency raised to 28.0.11.669 (the release containing `Confirm Gate ori`). App objects 10077050–10077063; test objects 97620–97627, 97629 (97622 covers Finish after posted output and consumption, backward flushing, consumption without output and outstanding subcontract orders and picks); under Omit Commit the BC commit is not suppressed and a BC error is raised to the caller, who rolls back.
- Let the full-role Create and Refresh test run under D365 BUS PREMIUM on BC 29, including Stockkeeping Unit and Warehouse Request reads (97608/97609). Accept either a strict Foundation `UnknownParameter` refusal or a collected `MultipleErrors` refusal that still names the undeclared key (97604, 97660). No record is written in either case.

- Give every test number series its own unique range and delete the production orders each committing test created (97604, 97605, 97607, 97608, 97610, 97615), so Create/Refresh tests pass on repeated runs in the same database instead of colliding on a fixed `X000001`; the Create caller-rollback test uses a unique manual number. Assertions unchanged.

- Verify the Manufacturing write gate against Foundation main without accepting message-envelope or test-helper permission errors (#15). Restricted-role tests grant the BOM/routing helpers and assertion library explicitly (97609/97664), supply the Foundation API transport role only for read-role dispatch, and check the same denial in both languages (97608). A separate role test confirms read cannot write the empty gate while Manufacturing and full roles can.

- Keep independent starting/ending dates and times plus a valid due date in the direction-comparison fixture (97605), and pass LCID plus Omit Commit together through Foundation’s public Temp Blob dispatcher overload (97607) so bilingual transaction tests exercise the requested language.

- Apply Gunnar’s 04 November Refresh transaction decision (#5): Refresh always commits, refuses Omit Commit before writes, and documents that boundary (10077042/10077043/10077045). Update native AC07–AC10 and AC13 tests (97605/97610) to the approved committing contract; Create retains caller rollback.

- Enforce the Manufacturing write role for Create, Refresh, BOM status and routing status even when native D365 roles grant broad codeunit Execute access (#5). Empty permission table 10077046 and check codeunit 10077047 distinguish full and read roles without widening native record access. Existing denial assertions now also reject misleading native licensing errors.

- Supply native Planning Assignment indirect insert/modify and Work Center read permissions in the shared permission-test baseline (97609); preserve distinct Manufacturing full/read grants and expose native refusal details in the full-role assertion (97608).

- Select the native report's transaction type before reading inside the normal Refresh rollback boundary and restore the caller's type after success or refusal (10077042/10077043); retain independent transaction-contract tests and add normal-boundary regression cases (97605).

- Record the owned MCP fixture company identity (97614) and provide explicit receipt cleanup after company removal (97616), with company/foreign-receipt isolation tests (97617).

- Add an isolated native refresh fixture control (97615) and explicit owned production-order fixture action (97667) for runtime diagnosis and MCP verification.

- Enable Premium experience in the shared Default/Test build container so all Manufacturing Refresh tests execute with the required platform configuration; retain every assertion and failure gate.

- Preserve bilingual BOM/routing test assertions in LCIDs 1033 and 1039 (codeunits 97660, 97661, 97663–97666); use Disabled isolation only for the ordinary-company background-session test 97613.

- Production order creation and refresh through `Manufacturing.ProductionOrder.Create` and `Manufacturing.ProductionOrder.Refresh` (#5). Native numbering, planning-only refresh, structured bilingual validation, conflict-aware identity lookup, Create caller rollback and explicit committing Refresh. App objects 10077039–10077045; test objects 97604–97613.
- Enforce the Manufacturing write role for Manufacturing.ProductionBOM.SetStatus and Manufacturing.Routing.SetStatus even when native D365 roles grant broad codeunit Execute access (#15). Empty permission table `Mfg Write Gate ori` (10077046) and check codeunit `Mfg Write Check ori` (10077047) are granted for write only by `BIFROST Mfg ori`/`BIFROST MfgFull ori`; `BIFROST MfgRead ori` gets read only. The gate objects are identical to those in #12 so there is one gate. Test permission set `BOM Rtg NoGrant ori` (97668) lets the restricted-role tests reach the gate, and 97664 now asserts the gate refuses (not a licence or helper error) in 1033 and 1039 and adds the gate-role test.

- Source Guards runs `tools/Test-MessageTypeNames.ps1` (self-test, then the app check) in a new `MessageTypeNames` job, the same as Foundation's, so every shipped message type name keeps exactly three parts (#12, AC20).

- Test-only fixture page 97667 exposes explicit setup/cleanup through the Web Client. Test library 97666 provides fresh XMFG8MCP fixtures for owned Web Client/MCP verification and verifies cleanup, including item units, planning assignments and owned change-log entries. AC09 tests (97660) refuse an undeclared key whether Foundation returns `UnknownParameter` or collected `MultipleErrors`, and they collect multiple invalid declared parameters separately.

- Correct status validation to run outside write-prohibited try functions (10077088/10077090). Scoped manual event subscriptions (10077092/10077093) suppress version commits only for the current call and release on error. Native tests use actual base permission sets, explicit language, and isolated change-log coverage.

- Scaffold: registration with Bifrost Foundation's application registry (`Mfg Registration ori`), permission set `BIFROST Mfg ori` with the Foundation role extensions `BIFROST MfgFull ori` and `BIFROST MfgRead ori`, Icelandic translation file, and a test app smoke (`Mfg Registration Tst ori`, own test suite MANUFACTUR).
- Manufacturing.ProductionBOM.SetStatus (`Prod BOM Status Impl ori` 10077087, `Prod BOM Status Proc ori` 10077088) and Manufacturing.Routing.SetStatus (`Routing Status Impl ori` 10077089, `Routing Status Proc ori` 10077090). Shared contract `Mfg BOMRtg Contract ori` 10077086, enum extension `Mfg BOMRtg MsgType ori` 10077085, write guard `BOM Routing Restrict ori` 10077091, commit suppression `BOM Routing Events ori` 10077092 and `BOM Routing Context ori` 10077093. Tests 97660–97666.
- The JSON field `status` stays the message outcome (`Success` or `Error`). The record status is `recordStatus` (`New`, `Certified`, `UnderDevelopment`, `Closed`). A production BOM header also returns `lowLevelCode` and `usedOnItems`. A routing header returns `usedOnItems` and not `lowLevelCode`. A version returns neither.
- `Data.Records.Set` of `Status` on production BOM header 99000771, production BOM version 99000779, routing header 99000763 and routing version 99000786 is refused. Foundation reports that dedicated-field refusal as `PermissionDenied` with a next step that names the message type. `BlockedByWriteGuard` is not the code Foundation returns for this hint.
- Closed and New are `InvalidParameter`. `PreconditionFailed` is documented and is not raised by these two types. The same status again returns `changed` false and writes nothing. Certification uses `Validate(Status)` and the standard Business Central checks. A version's own commit is suppressed only while the call runs.

## [28.0.0.0]

- Repository scaffolded from Bifrost Subscription Billing setup.
