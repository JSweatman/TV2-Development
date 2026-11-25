# NID directory expansion

This candidate includes the 232 geographical entries in the ITU National Numbering
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
232 entries in this ITU geographical directory plus 11 workbook territories
checked against Google libphonenumber metadata (243 rows total). Global satellite/network codes are excluded.
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

## Founder workbook reconciliation

The supplied “2026 Country Codes with Languages.xlsx” contains 280 numbered
rows plus blank/footer records. The workbook itself is not committed.
COUNTRY_WORKBOOK_RECONCILIATION.csv records each numbered row's disposition;
COUNTRY_LANGUAGE_NOTES.json preserves mapped language descriptions for review
only. It is not served by the resolver and does not set a default language or
expand English-only OPERATOR behavior. Multi-language strings are not BCP47 tags.

Åland is +358, American Samoa +1, and Guernsey/Jersey/Isle of Man +44;
national area-code suffixes are not NIDs. The 11 additional territory rows are
AX, GG, JE, IM, CX, CC, YT, BL, MF, VA, SJ. Country-code assignments were checked
against https://github.com/google/libphonenumber/blob/master/resources/PhoneNumberMetadata.xml
(retrieved 2026-11-25); no runtime dependency or imported phone rules are added.

Kazakhstan stays +7, shared with Russia; 997 is not added. ITU Operational
Bulletin 1341 (June 1 2026) confirms indefinite shared +7:
https://www.itu.int/dms_pub/itu-t/opb/sp/T-SP-OB.1341-2026-OAS-PDF-E.pdf
Vatican uses currently operational +39; the workbook's assigned 379 is not used.

Nine workbook labels remain review-only rather than invented separate IDs:
Artsakh, Australian Antarctic Territory, Australian External Territories,
French Antilles, Northern Cyprus, Pitcairn Islands, South Georgia and the South
Sandwich Islands, South Ossetia, Transnistria. Some are regional/aggregate labels,
some have uncertain operational coverage. Existing parent-country choices remain.
All service rows are excluded from the picker. No existing country ID or stored
selection is repurposed; existing database rows are preserved by the seed.
