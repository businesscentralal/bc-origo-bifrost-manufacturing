# Changelog

## Unreleased

- Production order creation and refresh through `Manufacturing.ProductionOrder.Create` and `Manufacturing.ProductionOrder.Refresh` (#5). Native numbering, planning-only refresh, structured bilingual validation, conflict-aware identity lookup and caller rollback. App objects 10077039–10077045; test objects 97604–97613.

- Scaffold: registration with Bifrost Foundation's application registry (`Mfg Registration ori`), permission set `BIFROST Mfg ori` with the Foundation role extensions `BIFROST MfgFull ori` and `BIFROST MfgRead ori`, Icelandic translation file, and a test app smoke (`Mfg Registration Tst ori`, own test suite MANUFACTUR). No message types yet.

## [28.0.0.0]

- Repository scaffolded from Bifrost Subscription Billing setup.
