# Extension: Bifrost Manufacturing

## Customer
Origo / AppSource

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.Manufacturing` namespace; same as Bifrost Subscription Billing)

## Namespace
Origo.Bifrost.Manufacturing (tests: Origo.Bifrost.Manufacturing.Test)

## Object ID Range
App:   10077035-10077134
Tests: 97600-97699

Allocated ids (record every new id here):

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
| 97667 | page (test only) | BOM Routing Fixtures ori |
| 97668 | permissionset (test) | BOM Rtg NoGrant ori |
| 97669-97679 | reserved | unused; the story name BOM Routing OmitCommit Tests ori is 32 characters, so 97665 uses the shortened name |

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
| 97622 | codeunit (test) | Prod Ord Finish Post Tests ori |
| 97623 | codeunit (test) | Mfg Omit Commit Tests ori |
| 97624 | codeunit (test) | Mfg Posting Gate Tests ori |
| 97625 | codeunit (test) | Prod Order Restrict Tests ori |
| 97626 | codeunit (test) | Mfg Status Contract Tests ori |
| 97627 | permissionset (test, no token) | Mfg NoPost Tst ori |
| 97629 | codeunit (test library) | Mfg Status Test Lib ori |

## Microsoft source
Business Central manufacturing (production orders, production BOMs, routings, work and machine centers, output and consumption) lives in the **Base Application**; BC 28 has no separate Microsoft manufacturing app to depend on. Source: https://github.com/microsoft/BCApps/tree/main/src/Layers/W1/BaseApp/Manufacturing
`main` of BCApps is a newer release than BC 28.5; read the matching `releases/28.x` branch when you need the exact 28.5 source.
Read it there before designing message types.

## Setup Notifications
Setup notifications live **only** on Bifröst Foundation's `Setup ori` page. This app never raises a `Notification` of its own.
It makes itself known to Foundation by subscribing to `App Registry ori.OnRegisterApps` and calling `AddApp` with this
app's module id, its display name and its setup page id (`0` while the app has no setup page). Follow
`app/src/Common/SubRegistration.Codeunit.al` in Bifrost Subscription Billing.

## Target BC Version
28.5 (application 28.5.0.0, platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-manufacturing
Default branch: main

## Dependencies
- Base Application (application floor 28.5.0.0)
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.11.669, same floor as Bifrost Subscription Billing)

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix), max 30 characters.
- The brand name "Bifrost" lives in the namespace, the app name ("Bifrost Manufacturing"), the permission sets and
  user-facing captions - never as an object-name prefix.
- Message type names have three parts: `Domain.Entity.Action`.
- Icelandic captions use "Bifröst".

## Development Standards

This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills: `origo-bc-al-coding-standards`, `origo-bc-test-writer`, `origo-bc-documentation-writer`.

Key rules always in effect:
- Namespace `Origo.Bifrost.Manufacturing` at the top of every app file (`Origo.Bifrost.Manufacturing.Test` in tests)
- XML documentation on every object and non-local procedure
- Bilingual captions (en-US + is-IS) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`, `.AsInteger()`, `.FromInteger()`
- Implementation = code + tests + documentation (the contract chapters of `Msg Contract ori`)

## Development Environment
- COSMO Alpaca containers are defined in `app/.vscode/launch.json` (git-ignored, the authority for instance ids).
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop; AL-Go CI is the gate for AppSource affix rules (AS0011).
- `app/AppSourceCop.json` sets `mandatoryAffixes`/`mandatorySuffix` to `ori` and the supported countries.
- Reference implementation: Bifrost Subscription Billing (businesscentralal/bc-origo-bifrost-subscription-billing).

## Message Type Conventions
- One enum extension of Foundation's `Message Type ori` with one value per type, named `Domain.Entity.Action`. These
  keys are the published external API contract and must never be renamed or removed.
- Each type has an Impl codeunit implementing `Msg Interface ori`, `Msg Discovery ori` and `Msg Contract ori`, with
  `TableNo = "Message Argument ori"` and an `OnRun` that runs its own write, as in Bifrost Subscription Billing.
- Errors are returned as `status = Error` with a helpful message; never let an unhandled exception reach the API.

## Test App Rules
- The test app uses Bifröst Foundation's public API only. Run message types through the public `Dispatcher ori`.

## Testing Through the MCP Server
- Keep MCP calls serial - parallel bursts crash the server.

Test fixture codeunit `97614 Mfg MCP Fixture Tst ori` seeds owned items, BOM, routing and numbering through native validation for MCP verification; it does not change write guards or consent. Licence test codeunit `97613` requires disabled test isolation because it starts a real background session, and cleans its own company and result record. Both isolation groups belong to the full configured suite.

Native fixture control `97615` runs the standard report using Microsoft's test-library transaction setup. It proves fixture validity separately; it does not replace or waive the dispatcher and caller-rollback tests.

Owned production-order MCP fixtures record their company name and SystemId in the global test receipt. After removing that owned company, run test codeunit 97616 to delete only its receipt; cleanup refuses while either the company identity or name exists. Codeunit 97617 covers removal, idempotence, foreign-receipt preservation and live/missing-company guards.

Manufacturing write messages require `BIFROST Mfg ori` or `BIFROST Full ori`.
The read role receives only read access to the empty permission gate; broad native
Execute grants do not confer Manufacturing write access. Native record permissions remain required.
