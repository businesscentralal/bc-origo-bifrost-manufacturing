# Bifröst Manufacturing

**App name:** Bifrost Manufacturing
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.5, runtime 17.0)
**App ID:** `bd08a710-8845-4316-a53b-afd28f21f75a` — **Test app ID:** `564eea9a-e27b-4358-bbae-28d380268382`
**Object ID range:** 10077035–10077134 (tests 97600–97699) — **Namespace:** `Origo.Bifrost.Manufacturing`

Bifrost Manufacturing will make the manufacturing area of Business Central callable from outside Business Central
through Bifröst message types: production orders, production BOMs, routings, work and machine centers, and output and
consumption, so an agent can operate it end to end. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Layers/W1/BaseApp/Manufacturing> (manufacturing is part of the Base Application)

**Status:** production order Create and Refresh implementation.

`Manufacturing.ProductionOrder.Create` creates a Planned or FirmPlanned item order using the configured number series. Call `Manufacturing.ProductionOrder.Refresh` to calculate lines, routing and components. Refresh refuses Released and Finished orders; it never posts. Both operations preserve the caller transaction under Omit Commit.

Use `describe_message_type` for parameter, response, error and workflow chapters. Ordinary field reads and edits remain with `Data.Records.Get` and `Data.Records.Set`.

---

## Object ranges

| Object | Range |
| --- | --- |
| App (`app/`) | 10077035-10077134 |
| Test app (`test/`) | 97600-97699 |

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://docs.bifrost.origo.is>.

| What | Where |
| --- | --- |
| Product documentation | <https://docs.bifrost.origo.is/en-us/manufacturing/> |
| Bifröst documentation home | <https://docs.bifrost.origo.is> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.5.590 |
| Base Application | | Microsoft | 28.5.0.0 (application floor) |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Manufacturing`), registration, permissions and production planning message types |
| `test/` | Test app (`Bifrost Manufacturing - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

## Production order objects (#5)

| ID | Object | Name |
| --- | --- | --- |
| 97604 | codeunit | Prod Order Create Tests ori |
| 97605 | codeunit | Prod Order Refresh Tests ori |
| 97606 | codeunit | Mfg ProdOrder Contract Tst ori |
| 97607 | codeunit | Mfg Test Data ori |
| 97610 | codeunit | Mfg ProdOrder Rollback Tst ori |
| 97604 | codeunit | Prod Order Create Tests ori |
| 97605 | codeunit | Prod Order Refresh Tests ori |
| 97606 | codeunit | Mfg ProdOrder Contract Tst ori |
| 97607 | codeunit | Mfg Test Data ori |
| 97608 | codeunit | Mfg ProdOrder Perm Tests ori |
| 97609 | permissionset | Mfg NoGrant Tst ori |
| 97610 | codeunit | Mfg ProdOrder Rollback Tst ori |
| 97611 | codeunit | Mfg Licence Probe Tst ori |
| 97612 | table | Mfg Licence Result Tst ori |
| 97613 | codeunit | Mfg Licence Tests ori |
| 10077039 | enumextension | Mfg ProdOrder MsgType ori |
| 10077040 | codeunit | Mfg ProdOrder Contract ori |
| 10077041 | codeunit | Prod Order Create Impl ori |
| 10077042 | codeunit | Prod Order Refresh Impl ori |
| 10077043 | codeunit | Prod Order Refresh Proc ori |
| 10077044 | codeunit | Mfg Prod Order Lookup ori |
| 10077045 | codeunit | Mfg Prod Order Request ori |

Test fixture codeunit `97614 Mfg MCP Fixture Tst ori` seeds owned items, BOM, routing and numbering through native validation for MCP verification; it does not change write guards or consent. Licence test codeunit `97613` requires disabled test isolation because it starts a real background session, and cleans its own company and result record. Both isolation groups belong to the full configured suite.
