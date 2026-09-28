# Country Policy Contract — intentionally incomplete

The country-policy socket exists so founder-approved country research can be added without rewriting identity parsing or the database API.

Current code model supports optional fields for:
- country code;
- base minimum length;
- base maximum length;
- initial language;
- initial locale;
- telephone-namespace rule/reference.

No country policy table is shipped as authoritative data in this checkpoint. That is deliberate. The founder is researching country-specific rules, and the system must not invent a universal telephone-number length or permanently bind a user to a Country Code-derived language.

Enrollment will eventually consume this policy. Public resolution should remain simpler: it looks up already-approved active identities within the chosen namespace.
