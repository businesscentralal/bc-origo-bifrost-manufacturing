# Changelog

## Unreleased

- Use processing-only report execution for headless production-order refresh (10077043), retaining the standard report and caller rollback boundary.

- Add a native refresh fixture regression (97605) and explicit owned production-order fixture action (97667) for runtime diagnosis and MCP verification.

- Enable Premium experience in the shared Default/Test build container so all Manufacturing Refresh tests execute with the required platform configuration; retain every assertion and failure gate.

- Preserve bilingual BOM/routing test assertions in LCIDs 1033 and 1039 (codeunits 97660, 97661, 97663–97666); use Disabled isolation only for the ordinary-company background-session test 97613.

- Production order creation and refresh through `Manufacturing.ProductionOrder.Create` and `Manufacturing.ProductionOrder.Refresh` (#5). Native numbering, planning-only refresh, structured bilingual validation, conflict-aware identity lookup and caller rollback. App objects 10077039–10077045; test objects 97604–97613.

- Test-only fixture page 97667 exposes explicit setup/cleanup through the Web Client. Test library 97666 provides fresh XMFG8MCP fixtures for owned Web Client/MCP verification and verifies cleanup, including item units, planning assignments and owned change-log entries. AC09 tests (97660) follow Foundation strict validation: an unknown key is refused before app validation; multiple invalid declared parameters are collected separately.

- Correct status validation to run outside write-prohibited try functions (10077088/10077090). Scoped manual event subscriptions (10077092/10077093) suppress version commits only for the current call and release on error. Native tests use actual base permission sets, explicit language, and isolated change-log coverage.

- Scaffold: registration with Bifrost Foundation's application registry (`Mfg Registration ori`), permission set `BIFROST Mfg ori` with the Foundation role extensions `BIFROST MfgFull ori` and `BIFROST MfgRead ori`, Icelandic translation file, and a test app smoke (`Mfg Registration Tst ori`, own test suite MANUFACTUR).
- Manufacturing.ProductionBOM.SetStatus (`Prod BOM Status Impl ori` 10077087, `Prod BOM Status Proc ori` 10077088) and Manufacturing.Routing.SetStatus (`Routing Status Impl ori` 10077089, `Routing Status Proc ori` 10077090). Shared contract `Mfg BOMRtg Contract ori` 10077086, enum extension `Mfg BOMRtg MsgType ori` 10077085, write guard `BOM Routing Restrict ori` 10077091, commit suppression `BOM Routing Events ori` 10077092 and `BOM Routing Context ori` 10077093. Tests 97660–97666.
- The JSON field `status` stays the message outcome (`Success` or `Error`). The record status is `recordStatus` (`New`, `Certified`, `UnderDevelopment`, `Closed`). A production BOM header also returns `lowLevelCode` and `usedOnItems`. A routing header returns `usedOnItems` and not `lowLevelCode`. A version returns neither.
- `Data.Records.Set` of `Status` on production BOM header 99000771, production BOM version 99000779, routing header 99000763 and routing version 99000786 is refused. Foundation reports that dedicated-field refusal as `PermissionDenied` with a next step that names the message type. `BlockedByWriteGuard` is not the code Foundation returns for this hint.
- Closed and New are `InvalidParameter`. `PreconditionFailed` is documented and is not raised by these two types. The same status again returns `changed` false and writes nothing. Certification uses `Validate(Status)` and the standard Business Central checks. A version's own commit is suppressed only while the call runs.

## [28.0.0.0]

- Repository scaffolded from Bifrost Subscription Billing setup.
