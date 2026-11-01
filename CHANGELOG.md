# Changelog

## Unreleased

- `Manufacturing.ProductionBOM.SetStatus` and `Manufacturing.Routing.SetStatus` to certify a production BOM or routing, or set it back to Under Development. Generic writes to the Status field are blocked (`BlockedByWriteGuard`).
- Scaffold: registration with Bifrost Foundation's application registry (`Mfg Registration ori`), permission set `BIFROST Mfg ori` with the Foundation role extensions `BIFROST MfgFull ori` and `BIFROST MfgRead ori`, Icelandic translation file, and a test app smoke (`Mfg Registration Tst ori`, own test suite MANUFACTUR). No message types yet.

## [28.0.0.0]

- Repository scaffolded from Bifrost Subscription Billing setup.
