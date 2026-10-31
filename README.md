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

**Status:** planning, no message types yet.

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
| `app/` | The AppSource app (`Bifrost Manufacturing`), no AL code yet |
| `test/` | Test app (`Bifrost Manufacturing - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |
