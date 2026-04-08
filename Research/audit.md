# Audit: swift-dual

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/modularization-audit-foundations-batch-B.md (2026-03-20)

**Modularization audit — MOD-001 through MOD-014**

1 product: Dual. 3 targets: Dual, Dual Macros, Dual Macros Implementation (macro target).

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Macros pattern |
| MOD-002 | PASS | Same structure as Defunctionalize — clean separation |
| MOD-003 | N/A | Not a variant package |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single product |
| MOD-006 | PASS | Minimal deps per target |
| MOD-007 | PASS | Depth 2 (Dual → Macros → Implementation) |
| MOD-008 | PASS | Main: 1, Macros: 1, Implementation: 8 |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `Dual`, `Dual Macros` — correct L3 naming |
| MOD-013 | N/A | 4 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-011). Same pattern as Defunctionalize.
