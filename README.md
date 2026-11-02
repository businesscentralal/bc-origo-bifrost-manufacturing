# Bifröst Manufacturing

**App name:** Bifrost Manufacturing
**Publisher:** Origo — **Version:** 28.0.2.0 — **Target:** Cloud (BC 28.0 application floor, runtime 17.0)
**App ID:** `bd08a710-8845-4316-a53b-afd28f21f75a` — **Test app ID:** `564eea9a-e27b-4358-bbae-28d380268382`
**Object ID range:** 10077035–10077134 (tests 97600–97699) — **Namespace:** `Origo.Bifrost.Manufacturing`

## Overview

Bifrost Manufacturing makes production orders, production journals, production BOMs, routings, calendars, planning,
and warehouse actions callable through Bifröst message types. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Layers/W1/BaseApp/Manufacturing> (manufacturing is part of the Base Application)

**Status:** Implements Manufacturing.ProductionBOM.SetStatus and Manufacturing.Routing.SetStatus, plus message types for production orders, production journals and reversals, BOMs, routings, calendar and absence application/removal, planning, and production warehouse picks and output put-aways. Subcontract purchase-order creation is provided by Bifrost Subcontracting. Verification of the combined candidate remains pending.

## Functional Flow

1. A caller selects a `Manufacturing.*` message type and provides its JSON parameters.
2. Bifrost Foundation dispatches the request to this app's message implementation.
3. The implementation validates the requested manufacturing records and invokes the corresponding Business Central operation.
4. The response reports success or returns the operation error.

## Benefits

- Call production workflows through the same Bifröst dispatcher used by other apps.
- Keep production data access under the invoking user's Business Central permissions.
- Use Microsoft manufacturing and warehouse operations rather than duplicating their business rules.

## Logic Flow

`Caller -> Bifrost Foundation Dispatcher -> Manufacturing message implementation -> Business Central manufacturing operation -> JSON response`

Subcontract purchase-order creation is handled separately by Bifrost Subcontracting.

## Setup & Configuration

Install Bifrost Foundation and assign the Bifrost Manufacturing permission set alongside the appropriate Bifrost Core permissions. The caller also needs its normal Business Central permissions for the records and operations it invokes.

## Example Scenario

Refresh one released production order:

```json
{
	"type": "Manufacturing.ProductionOrder.Refresh",
	"subject": "X-PROD-0001",
	"data": {}
}
```

## Objects

| Id | Object | Name |
| --- | --- | --- |
| 10077035 | codeunit | Mfg Registration ori |
| 10077036 | permissionset | BIFROST Mfg ori |
| 10077037 | permissionsetextension | BIFROST MfgFull ori |
| 10077038 | permissionsetextension | BIFROST MfgRead ori |
| 10077039 | enumextension | Mfg Msg Type ori |
| 10077040 | codeunit | Mfg Refresh Order Impl ori |
| 10077044 | codeunit | Mfg Calc Consumption Impl ori |
| 10077047 | codeunit | Mfg Journal Reverse Impl ori |
| 10077048 | codeunit | Mfg Prod BOM Impl ori |
| 10077050 | codeunit | Mfg Routing Impl ori |
| 10077052 | codeunit | Mfg Calendar Impl ori |
| 10077053 | codeunit | Mfg Absence Impl ori |
| 10077054 | codeunit | Mfg Plan Calc Impl ori |
| 10077055 | codeunit | Mfg Plan Carryout Impl ori |
| 10077057 | codeunit | Mfg Warehouse Impl ori |
| 10077059 | enum value | Manufacturing.Calendar.RemoveAbsence |
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
| 97603 | codeunit (test) | Mfg Refresh Order Tst ori |
| 97603 | permissionset (test) | Mfg Platform Tst ori |
| 97604 | codeunit (test) | Mfg Journal Tst ori |
| 97605 | codeunit (test) | Mfg BOM Tst ori |
| 97606 | codeunit (test) | Mfg Routing Tst ori |
| 97607 | codeunit (test) | Mfg Calendar Tst ori |
| 97608 | codeunit (test) | Mfg Absence Tst ori |
| 97609 | codeunit (test) | Mfg Plan Tst ori |
| 97610 | codeunit (test) | Mfg Plan Carryout Tst ori |
| 97612 | codeunit (test) | Mfg Warehouse Tst ori |
| 97660 | codeunit (test) | Prod BOM Status Tests ori |
| 97661 | codeunit (test) | Routing Status Tests ori |
| 97662 | codeunit (test) | BOM Routing Restrict Tests ori |
| 97663 | codeunit (test) | BOM Routing Contract Tests ori |
| 97664 | codeunit (test) | BOM Routing Perm Tests ori |
| 97665 | codeunit (test) | BOM Rtg OmitCommit Tests ori |
| 97666 | codeunit (test) | BOM Routing Test Lib ori |
| 97667 | page (test only) | BOM Routing Fixtures ori |
| 97668-97679 | reserved | unused; the story name BOM Routing OmitCommit Tests ori is 32 characters, so 97665 uses the shortened name |

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
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.10.632 |
| Base Application | | Microsoft | 28.0.0.0 (application floor) |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Manufacturing`), message types, registration, and permission sets |
| `test/` | Test app (`Bifrost Manufacturing - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |
