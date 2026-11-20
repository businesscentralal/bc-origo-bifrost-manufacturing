# Production order reads — issue 26

Issue: https://github.com/businesscentralal/bc-origo-bifrost-manufacturing/issues/26

Gunnar approved wave 1 on 20 November 2026. Help chapters remain English;
discovery text, refusals and next steps are translated to Icelandic.

| Criterion | Implementation | Verification |
| --- | --- | --- |
| AC01 component shortage and replenishment | Pending | Pending AL + MCP |
| AC02 standard, expected and actual costs after posting and adjustment | Pending | Pending native parity + MCP |
| AC03 unknown order/status and finished availability refusal | Pending | Pending AL |
| AC04 read role and no-permission caller | Pending | Pending AL |
| C1 coded refusals, next steps, error log and unchanged business records | Pending | Pending AL |
| C2 English chapters, translated discovery/refusals, no en-US XLF | Pending | Pending 1033/1039 help + XLF |
| C3 self-seeded data on W1 and IS | Pending | Pending w129-20 / is29-20 |
| C4 no UI change | No UI planned | No clips required by story |

Licence-path checks: NOT_RUN per task rules; verified before release.
Full-suite evidence will be the paired CI run at the final PR head.
