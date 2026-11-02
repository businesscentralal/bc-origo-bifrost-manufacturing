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

**Status:** Manufacturing.ProductionBOM.SetStatus and Manufacturing.Routing.SetStatus are implemented. Production-order refresh is not in this app yet.

---

## Object ranges

| Object | Range |
| --- | --- |
| App (`app/`) | 10077035-10077134 |
| Test app (`test/`) | 97600-97699 |

---

## Allocated objects

| Id | Object | Name |
| --- | --- | --- |
| 10077035 | codeunit | Mfg Registration ori |
| 10077036 | permissionset | BIFROST Mfg ori |
| 10077037 | permissionsetextension | BIFROST MfgFull ori |
| 10077038 | permissionsetextension | BIFROST MfgRead ori |
| 10077085 | enumextension | Mfg BOMRtg MsgType ori |
| 10077086 | codeunit | Mfg BOMRtg Contract ori |
| 10077087 | codeunit | Prod BOM Status Impl ori |
| 10077088 | codeunit | Prod BOM Status Proc ori |
| 10077089 | codeunit | Routing Status Impl ori |
| 10077090 | codeunit | Routing Status Proc ori |
| 10077091 | codeunit | BOM Routing Restrict ori |
| 10077092 | codeunit | BOM Routing Events ori |
| 10077093 | codeunit | BOM Routing Context ori |
| 10077094-10077104 | reserved | unused; do not reuse without recording the object |
| 97600 | codeunit (test) | Mfg Test Install ori |
| 97601 | codeunit (test) | Mfg Test Upgrade ori |
| 97602 | codeunit (test) | Mfg Registration Tst ori |
| 97603 | permissionset (test) | Mfg Platform Tst ori |
| 97660 | codeunit (test) | Prod BOM Status Tests ori |
| 97661 | codeunit (test) | Routing Status Tests ori |
| 97662 | codeunit (test) | BOM Routing Restrict Tests ori |
| 97663 | codeunit (test) | BOM Routing Contract Tests ori |
| 97664 | codeunit (test) | BOM Routing Perm Tests ori |
| 97665 | codeunit (test) | BOM Rtg OmitCommit Tests ori |
| 97666 | codeunit (test) | BOM Routing Test Lib ori |
| 97667-97679 | reserved | unused; the story name BOM Routing OmitCommit Tests ori is 32 characters, so 97665 uses the shortened name |

The version commit suppression uses a locally bound manual subscriber. Its lifetime is the status call, including exception unwinding; the single-instance context reports that binding without retaining a Boolean after an error.

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
| `app/` | The AppSource app (`Bifrost Manufacturing`), registration, permission sets, and the production BOM and routing status message types |
| `test/` | Test app (`Bifrost Manufacturing - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |
