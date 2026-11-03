# Changelog

## Unreleased

- Permission test AC16 (`BOM Routing Perm Tests ori` 97664, library 97666) accepts either a raised platform permission error or an Error answer reporting the permission failure when `BIFROST Read ori` dispatches the BOM and routing status types. Foundation 28.0.11 enqueues with inherent permissions (core#1236), so the refusal is answered instead of raised. The library lowers permissions inside its own run, and a permission error on the test library itself now fails the test instead of passing it.

- Test fixture cleanup (`Mfg Posting Fixture ori` 97616) also removes the owned order's capacity ledger entries, average-cost adjustment entry points and output put-away/pick activities, and verifies they are gone. Owned MCP verification found these left behind after posting, reversing and finishing a fixture order.

- Refuse same-status production-order changes and already-applied or correcting output reversals with `PreconditionFailed` before standard posting (10077040/10077047). Native regressions 97614/97615 exercise unchanged orders and a real post/reverse/repeat sequence.

- Select Update isolation before the production transaction begins, matching the standard refresh report while retaining exact-order locks and native execution (10077040).

- Synchronize the existing Icelandic label translations for the manufacturing actions into the application XLF file.

- Source Guards runs `tools/Test-MessageTypeNames.ps1` (self-test, then the app check) in a new `MessageTypeNames` job, the same as Foundation's, so every shipped message type name keeps exactly three parts (#12, AC20).

- Test-only fixture page 97667 exposes explicit setup/cleanup through the Web Client. Test library 97666 provides fresh XMFG8MCP fixtures for owned Web Client/MCP verification and verifies cleanup, including item units, planning assignments and owned change-log entries. AC09 tests (97660) follow Foundation strict validation: an unknown key is refused before app validation; multiple invalid declared parameters are collected separately.

- Correct status validation to run outside write-prohibited try functions (10077088/10077090). Scoped manual event subscriptions (10077092/10077093) suppress version commits only for the current call and release on error. Native tests use actual base permission sets, explicit language, and isolated change-log coverage.

- Scaffold: registration with Bifrost Foundation's application registry (`Mfg Registration ori`), permission set `BIFROST Mfg ori` with the Foundation role extensions `BIFROST MfgFull ori` and `BIFROST MfgRead ori`, Icelandic translation file, and a test app smoke (`Mfg Registration Tst ori`, own test suite MANUFACTUR).
- Manufacturing.ProductionBOM.SetStatus (`Prod BOM Status Impl ori` 10077087, `Prod BOM Status Proc ori` 10077088) and Manufacturing.Routing.SetStatus (`Routing Status Impl ori` 10077089, `Routing Status Proc ori` 10077090). Shared contract `Mfg BOMRtg Contract ori` 10077086, enum extension `Mfg BOMRtg MsgType ori` 10077085, write guard `BOM Routing Restrict ori` 10077091, commit suppression `BOM Routing Events ori` 10077092 and `BOM Routing Context ori` 10077093. Tests 97660–97666.
- The JSON field `status` stays the message outcome (`Success` or `Error`). The record status is `recordStatus` (`New`, `Certified`, `UnderDevelopment`, `Closed`). A production BOM header also returns `lowLevelCode` and `usedOnItems`. A routing header returns `usedOnItems` and not `lowLevelCode`. A version returns neither.
- `Data.Records.Set` of `Status` on production BOM header 99000771, production BOM version 99000779, routing header 99000763 and routing version 99000786 is refused. Foundation reports that dedicated-field refusal as `PermissionDenied` with a next step that names the message type. `BlockedByWriteGuard` is not the code Foundation returns for this hint.
- Closed and New are `InvalidParameter`. `PreconditionFailed` is documented and is not raised by these two types. The same status again returns `changed` false and writes nothing. Certification uses `Validate(Status)` and the standard Business Central checks. A version's own commit is suppressed only while the call runs.

## [28.0.2.0] - 2026-11-02

### Added
- Added production warehouse picks and output put-aways (10077057).
- Added production journal posting reversal for item and capacity ledger entries.
- Added message types for production-order refresh, replan, status changes, and cost recalculation.

### Changed
- Production reversal (10077047) accepts Foundation’s shared `expectedCount` confirmation parameter and validates its single target on the minimum Foundation dependency. Native reversal tests explicitly confirm their one owned entry, retaining the exact missing-parameter/state/ledger assertions.
- Standard journal posting runs with a scoped manual dialog subscriber (10077061) so API calls do not wait for confirmation. Reversal (10077047) checks ledger read and correcting-journal write permission; standard posting retains enforcement of indirect ledger rights. Tests 97615/97616 prove output posting with owned accounting fixtures; test page 97617 exposes explicit setup/message execution/verified cleanup.
- Production actions (10077040/10077044/10077047/10077057) use shared coded validation (10077060), explicit permissions, locked target/state checks and pre-write Omit Commit refusals. Refresh explicitly initializes calculations; ChangeStatus resolves one active composite-key record and returns the resulting order number. Regression tests 97613/97614 exercise refusals, restricted roles and actual order/line changes.
- Synchronize en-US/is-IS product and test XLF files; align the test dependency with Manufacturing 28.0.2.0.
- Retain the BC 28.5 application floor and limit this PR to the approved production-order lifecycle. Remove nine unapproved BOM, routing, calendar and planning action types and their implementation/tests; existing main BOM/routing status features remain.
- Added `Manufacturing.Journal.CalculateConsumption`, `Manufacturing.Journal.ExplodeRouting`, and `Manufacturing.Journal.Post` for batch-scoped production journal operations.

## [28.0.0.0]

- Repository scaffolded from Bifrost Subscription Billing setup.
