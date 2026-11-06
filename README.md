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

**Status:** production order Create/Refresh and production BOM/routing SetStatus are implemented.

`Manufacturing.ProductionOrder.Create` creates a Planned or FirmPlanned item order using the configured number series. Call `Manufacturing.ProductionOrder.Refresh` to calculate lines, routing and components. Refresh refuses Released and Finished orders; it never posts. Create preserves the caller transaction under Omit Commit. Refresh always commits because the native BC report commits internally; it refuses Omit Commit with `PreconditionFailed` before any write. Run Refresh as a separate committing operation.

Use `describe_message_type` for parameter, response, error and workflow chapters. Ordinary field reads and edits remain with `Data.Records.Get` and `Data.Records.Set`.

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
| 10077039 | enumextension | Mfg ProdOrder MsgType ori |
| 10077040 | codeunit | Mfg ProdOrder Contract ori |
| 10077041 | codeunit | Prod Order Create Impl ori |
| 10077042 | codeunit | Prod Order Refresh Impl ori |
| 10077043 | codeunit | Prod Order Refresh Proc ori |
| 10077044 | codeunit | Mfg Prod Order Lookup ori |
| 10077045 | codeunit | Mfg Prod Order Request ori |
| 10077046 | table | Mfg Write Gate ori |
| 10077047 | codeunit | Mfg Write Check ori |
| 10077050 | table | Mfg Posting ori |
| 10077051 | permissionset | BIFROST MfgPost ori |
| 10077052 | enumextension | Mfg Status MsgType ori |
| 10077053 | codeunit | Mfg Posting Gate ori |
| 10077054 | codeunit | Mfg Status Contract ori |
| 10077055 | codeunit | Prod Order Status Impl ori |
| 10077056 | codeunit | Prod Order Status Proc ori |
| 10077057 | codeunit | Prod Order Finish Impl ori |
| 10077058 | codeunit | Prod Order Finish Proc ori |
| 10077059 | codeunit | Prod Ord Fin Check Impl ori |
| 10077060 | codeunit | Prod Order Finish Check ori |
| 10077061 | codeunit | Prod Order Confirm ori |
| 10077062 | codeunit | Prod Order Restrict ori |
| 10077063 | codeunit | Mfg Write Context ori |
| 10077070 | enumextension | Mfg ProdJnl MsgType ori |
| 10077071 | codeunit | Mfg ProdJnl Contract ori |
| 10077072 | codeunit (Manufacturing.ProductionJournal.Get) | Prod Jnl Get Impl ori |
| 10077073 | codeunit (Manufacturing.ProductionJournal.PreviewPost) | Prod Jnl Preview Impl ori |
| 10077074 | codeunit (Manufacturing.ProductionJournal.Post) | Prod Jnl Post Impl ori |
| 10077075 | codeunit (Codeunit.Run boundary) | Prod Jnl Post Proc ori |
| 10077076 | codeunit (builder) | Prod Jnl Builder ori |
| 10077078 | codeunit (context and date/basis subscriber) | Prod Jnl Events ori |
| 10077079 | codeunit (confirm counter) | Prod Jnl Confirm ori |
| 10077080 | codeunit (request reader) | Prod Jnl Request ori |
| 97640 | codeunit (test) | Prod Jnl Get Tests ori |
| 97642 | codeunit (test) | Prod Jnl Post Tests ori |
| 97645 | codeunit (test) | Prod Jnl Contract Tests ori |
| 97647 | codeunit (test library) | Prod Jnl Test Lib ori |
| 97620 | codeunit (test) | Prod Order Status Tests ori |
| 97621 | codeunit (test) | Prod Order Finish Tests ori |
| 97623 | codeunit (test) | Mfg Omit Commit Tests ori |
| 97624 | codeunit (test) | Mfg Posting Gate Tests ori |
| 97625 | codeunit (test) | Prod Order Restrict Tests ori |
| 97626 | codeunit (test) | Mfg Status Contract Tests ori |
| 97627 | permissionset (test, no token) | Mfg NoPost Tst ori |
| 97629 | codeunit (test library) | Mfg Status Test Lib ori |
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
| 97604 | codeunit (test) | Prod Order Create Tests ori |
| 97605 | codeunit (test) | Prod Order Refresh Tests ori |
| 97606 | codeunit (test) | Mfg ProdOrder Contract Tst ori |
| 97607 | codeunit (test) | Mfg Test Data ori |
| 97608 | codeunit (test) | Mfg ProdOrder Perm Tests ori |
| 97609 | permissionset (test) | Mfg NoGrant Tst ori |
| 97610 | codeunit (test) | Mfg ProdOrder Rollback Tst ori |
| 97611 | codeunit (test) | Mfg Licence Probe Tst ori |
| 97612 | table (test) | Mfg Licence Result Tst ori |
| 97613 | codeunit (test) | Mfg Licence Tests ori |
| 97614 | codeunit (test fixture) | Mfg MCP Fixture Tst ori |
| 97615 | codeunit (test) | Mfg Native Refresh Tst ori |
| 97616 | codeunit (test cleanup) | Mfg MCP Cleanup Tst ori |
| 97617 | codeunit (test) | Mfg MCP Cleanup Tests ori |
| 97660 | codeunit (test) | Prod BOM Status Tests ori |
| 97661 | codeunit (test) | Routing Status Tests ori |
| 97662 | codeunit (test) | BOM Routing Restrict Tests ori |
| 97663 | codeunit (test) | BOM Routing Contract Tests ori |
| 97664 | codeunit (test) | BOM Routing Perm Tests ori |
| 97665 | codeunit (test) | BOM Rtg OmitCommit Tests ori |
| 97666 | codeunit (test) | BOM Routing Test Lib ori |
| 97667 | page (test only) | BOM Routing Fixtures ori |
| 97668 | permissionset (test) | BOM Rtg NoGrant ori |
| 97669-97679 | reserved | unused; the story name BOM Routing OmitCommit Tests ori is 32 characters, so 97665 uses the shortened name |

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
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.11.669 |
| Base Application | | Microsoft | 28.5.0.0 (application floor) |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Manufacturing`), registration, permission sets, production planning, and production BOM and routing status message types |
| `test/` | Test app (`Bifrost Manufacturing - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

Owned production-order MCP fixtures record their company name and SystemId in the global test receipt. After removing that owned company, run test codeunit 97616 to delete only its receipt; cleanup refuses while either the company identity or name exists. Codeunit 97617 covers removal, idempotence, foreign-receipt preservation and live/missing-company guards.

Manufacturing write messages require `BIFROST Mfg ori` or `BIFROST Full ori`.
The read role receives only read access to the empty permission gate; broad native
Execute grants do not confer Manufacturing write access. Native record permissions remain required.

Permission regressions run through Foundation’s public dispatcher. Read-role dispatch tests
also assign `BIFROST API ori` for the persisted message envelope; that transport role
does not grant write access to the Manufacturing gate. Test-only helper Execute grants
keep the checks independent of test order. Full-role success and missing native table
permissions are checked separately in fresh sessions on Foundation main.
