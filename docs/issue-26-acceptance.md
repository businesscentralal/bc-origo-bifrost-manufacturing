# Production order reads — issue 26

Issue: https://github.com/businesscentralal/bc-origo-bifrost-manufacturing/issues/26

Gunnar approved wave 1 on 20 November 2026. Help chapters remain English;
discovery text, refusals and next steps are translated to Icelandic.
The PR's single Current state comment records the verified/pending status,
full candidate SHA, counts and receipts for this acceptance map.

| Criterion | Implementation | Verification |
| --- | --- | --- |
| AC01 component shortage and replenishment | Implemented; shortage-list priorities and reservations, base units | AL stock posting test; MCP 2 on hand / 5 needed, then journal replenishment |
| AC02 standard, expected and actual costs | Implemented using native Statistics cost routines | AL native parity after consumption, output, finish and cost adjustment; MCP known 10 LCY fixture |
| AC03 unknown order/status and finished availability refusal | Implemented | AL and bilingual MCP refusals |
| AC04 read role and no-permission caller | Implemented; existing Manufacturing gate, object-level native read Permissions | Restricted-role AL tests in 1033/1039 |
| C1 coded refusals, next steps, error log and unchanged business records | Implemented through Foundation error responses | AL per-code/no-write tests; public task/response API log receipt |
| C2 English chapters and translated discovery/refusals | Implemented; optional Inventory references only when installed | AL contract test; 1033/1039 help and XLF receipts |
| C3 self-seeded data on W1 and IS | Raw records plus native journal posting; owned fixture cleanup restores setup | Own w129-20 and is29-20 native/MCP receipts |
| C4 no UI change | No product page or action changed | No clips required by story |

All cost totals use top-level lines as in Statistics. Material includes any enabled
non-inventory material cost. Capacity uses the configured display unit; a selected
line uses its routing reference and share of shared capacity. Scrap is the sum of
posted operation scrap. Availability is a snapshot, not a reservation.

Compiler constraints: AppSource permission-set extensions cannot grant Microsoft
objects, and InherentPermissions only accepts objects from the current extension.
The implementations therefore use object-level native read Permissions after the
Manufacturing read-role gate; normal BC user permissions still apply. No warning
suppression or new assignable product role was introduced.

Licence-path checks: NOT_RUN per task rules; verified before release.
Full-suite evidence is the paired CI run at the final PR head.
