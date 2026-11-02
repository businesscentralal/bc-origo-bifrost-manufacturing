# Changelog

## [28.0.2.0] - 2026-11-02

### Added
- Added message types for production BOM and routing checks and copies, calendar recalculation and absence application/removal, planning calculation and carry-out, and production warehouse picks and output put-aways.
- Added production journal posting reversal for item and capacity ledger entries.
- Added message types for production-order refresh, replan, status changes, and cost recalculation.

### Changed
- Moved `Manufacturing.Subcontracting.CreatePurchaseOrders` to Bifrost Subcontracting without changing its public message key.
- Added `Manufacturing.Journal.CalculateConsumption`, `Manufacturing.Journal.ExplodeRouting`, and `Manufacturing.Journal.Post` for batch-scoped production journal operations.
- Updated the minimum Business Central application version to 28.0.0.0.

## [28.0.0.0]

- Repository scaffolded from Bifrost Subscription Billing setup.
