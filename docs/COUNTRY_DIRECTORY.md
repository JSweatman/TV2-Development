# NID directory expansion

This candidate adds the 232 geographical entries in the ITU National Numbering
Plans directory retrieved 2026-11-25:
https://www.itu.int/oth/t0202/en

The checked-in JSON is a reviewed snapshot, not a runtime remote download.
NIDs are dialing namespaces, not national telephone numbers. NANP area codes
are reduced to shared +1, retaining TV2's single visible +1 choice. Shared +7
and other existing shared codes retain country rows. No enrollment length,
language inference, account, listings, or routing policy is added.

Names follow ITU geographical labels. ISO identifiers were matched against the
system ISO 3166-1 data, with explicit mappings for ITU abbreviated names.
AC and XK are compatibility identifiers, not a claim of ISO assignment.
The ITU group “French Departments and Territories in the Indian Ocean” uses RE;
“Saint Helena and Tristan da Cunha” uses SH; Diego Garcia uses IO. This is all
232 entries in this ITU geographical directory, not every ISO territory as a
separate selectable row. Global satellite/network codes are excluded.
Existing five language tags are retained; added entries have no inferred language.

## Delivery boundary

The live API reads active `country_namespaces` rows from the connected database.
Changing the fixture alone does not change the live picker. The additive seed
`backend/sql/004_country_directory.sql` inserts absent rows only, preserving all
existing names, NIDs, language tags and disabled rows. It changes no grants/RLS.
No automatic deployment or migration runner is added.

Before applying, verify the deployed table's columns/types/defaults and unique
keys; compare all existing rows against the JSON and review mismatches. Record
which ISO identifiers are absent before applying. Apply in a reviewed transaction
and verify `/v1/countries` plus the actual PWA picker before release. Rollback
must remove only identifiers recorded as inserted by this rollout, after checking
references; do not blanket-delete the catalog or reactivate disabled rows.

Fixtures and API tests use this full snapshot. Existing parser behavior remains:
a newly selectable country does not invent a listing. No live DB write is part
of this implementation. Physical phone and installed-PWA validation are separate.
