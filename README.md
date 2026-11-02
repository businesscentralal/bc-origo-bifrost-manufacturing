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

**Status:** Implements message types for production orders, production journals and reversals, BOMs, routings, calendar and absence application/removal, planning, and production warehouse picks and output put-aways. Subcontract purchase-order creation is provided by Bifrost Subcontracting. The app builds and is published to Kappi. Container tests remain unverified: the test app is still at 28.0.0.0 and the runner returned an empty suite.

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

| ID | Object | Name |
| --- | --- | --- |
| 10077035 | Codeunit | Mfg Registration ori |
| 10077036 | Permission set | BIFROST Mfg ori |
| 10077037 | Permission set extension | BIFROST MfgFull ori |
| 10077038 | Permission set extension | BIFROST MfgRead ori |
| 10077039 | Enum extension | Mfg Msg Type ori |
| 10077040 | Codeunit | Mfg Refresh Order Impl ori |
| 10077044 | Codeunit | Mfg Calc Consumption Impl ori |
| 10077047 | Codeunit | Mfg Journal Reverse Impl ori |
| 10077048 | Codeunit | Mfg Prod BOM Impl ori |
| 10077050 | Codeunit | Mfg Routing Impl ori |
| 10077052 | Codeunit | Mfg Calendar Impl ori |
| 10077053 | Codeunit | Mfg Absence Impl ori |
| 10077054 | Codeunit | Mfg Plan Calc Impl ori |
| 10077055 | Codeunit | Mfg Plan Carryout Impl ori |
| 10077057 | Codeunit | Mfg Warehouse Impl ori |

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
