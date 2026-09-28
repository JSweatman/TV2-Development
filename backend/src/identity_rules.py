"""Pure TV2 List Number input rules.

This module validates List Number grammar only. Country-specific allocation,
telephone-number protection, reserved ranges, and language policy belong to the
country-policy/enrollment layer and MUST NOT be hard-coded here.
"""
from __future__ import annotations
from dataclasses import dataclass

ALLOWED_IDENTITY_CHARS = frozenset("0123456789@/-#.")
SYMBOLS = frozenset("@/-#.")
BASE_SYMBOLS = frozenset("@/-#")
MAX_BASE_LENGTH = 15
MAX_TRANSPORT_INPUT_LENGTH = 64  # transport guardrail, not an identifier policy


class InvalidIdentity(ValueError):
    """Raised when input violates the platform grammar."""


@dataclass(frozen=True)
class ParsedIdentity:
    country_code: str | None
    base: str
    tldx: str | None
    is_global: bool

    @property
    def canonical(self) -> str:
        body = self.base if self.tldx is None else f"{self.base}.{self.tldx}"
        return f"*{body}" if self.is_global else body


def _validate_country_context(country: str | None) -> str | None:
    if country is None:
        return None
    if not isinstance(country, str) or not country or not country.isascii() or not country.isdecimal():
        raise InvalidIdentity("Country context must be numeric.")
    return country


def _validate_body(value: str) -> tuple[str, str | None]:
    if not value:
        raise InvalidIdentity("A List Number is required.")
    if any(ch not in ALLOWED_IDENTITY_CHARS for ch in value):
        raise InvalidIdentity("Unsupported List Number character.")
    if "*" in value:
        # '*' is a namespace separator / Global Code marker, not a base character.
        raise InvalidIdentity("STAR is reserved for namespace selection.")
    if value.count(".") > 1:
        raise InvalidIdentity("At most one TLDx separator is allowed.")

    if "." in value:
        base, tldx = value.split(".", 1)
        if not tldx:
            raise InvalidIdentity("TLDx cannot be empty.")
    else:
        base, tldx = value, None

    if not base:
        raise InvalidIdentity("Base List Number is required.")
    if len(base) > MAX_BASE_LENGTH:
        raise InvalidIdentity(f"Base List Number must contain 1–{MAX_BASE_LENGTH} characters.")
    if not any(ch.isdigit() for ch in base):
        raise InvalidIdentity("Base List Number must contain a digit.")
    if base[-1] in BASE_SYMBOLS:
        raise InvalidIdentity("Base List Number cannot end with a symbol.")

    # No adjacent non-alphabet symbols anywhere in the base or TLDx body. The
    # dot is a separator, so the first TLDx character must also be non-symbolic.
    if any(a in SYMBOLS and b in SYMBOLS for a, b in zip(value, value[1:])):
        raise InvalidIdentity("Adjacent symbols are not allowed.")
    if tldx is not None and tldx[-1] in SYMBOLS:
        raise InvalidIdentity("TLDx cannot end with a symbol.")

    return base, tldx


def parse_identity(raw: str, requested_country: str | None = "1") -> ParsedIdentity:
    """Parse a user-entered List Number into namespace + base + optional TLDx.

    Rules intentionally *do not* decide whether the identifier can be enrolled.
    Enrollment eligibility (including telephone-number holder verification) is a
    separate country-policy decision.
    """
    if not isinstance(raw, str) or not raw:
        raise InvalidIdentity("Identity input is required.")
    if len(raw) > MAX_TRANSPORT_INPUT_LENGTH:
        raise InvalidIdentity("Identity input is too long for this interface.")

    if raw.startswith("*"):
        if raw.count("*") != 1:
            raise InvalidIdentity("Invalid Global Code syntax.")
        country = None
        value = raw[1:]
        is_global = True
    elif "*" in raw:
        if raw.count("*") != 1:
            raise InvalidIdentity("Invalid country namespace syntax.")
        prefix, value = raw.split("*", 1)
        country = _validate_country_context(prefix)
        is_global = False
    else:
        country = _validate_country_context(requested_country)
        if country is None:
            raise InvalidIdentity("Country context is required for a non-global List Number.")
        value = raw
        is_global = False

    base, tldx = _validate_body(value)
    return ParsedIdentity(country_code=country, base=base, tldx=tldx, is_global=is_global)


def parse_prefix(raw: str, requested_country: str | None = "1") -> ParsedIdentity:
    """Parse progressive input without treating a temporary trailing symbol as final.

    This is intentionally more permissive than :func:`parse_identity` because a
    user can pause after entering an extension separator while still composing a
    valid identifier. It never makes an incomplete value resolvable as an exact
    identity; exact resolution always uses the strict parser.
    """
    if not isinstance(raw, str) or not raw:
        raise InvalidIdentity("Identity input is required.")
    if len(raw) > MAX_TRANSPORT_INPUT_LENGTH:
        raise InvalidIdentity("Identity input is too long for this interface.")

    if raw.startswith("*"):
        if raw.count("*") != 1:
            raise InvalidIdentity("Invalid Global Code syntax.")
        country, value, is_global = None, raw[1:], True
    elif "*" in raw:
        if raw.count("*") != 1:
            raise InvalidIdentity("Invalid country namespace syntax.")
        prefix, value = raw.split("*", 1)
        country, is_global = _validate_country_context(prefix), False
    else:
        country = _validate_country_context(requested_country)
        if country is None:
            raise InvalidIdentity("Country context is required for a non-global List Number.")
        value, is_global = raw, False

    if any(ch not in ALLOWED_IDENTITY_CHARS for ch in value):
        raise InvalidIdentity("Unsupported List Number character.")
    if "*" in value:
        raise InvalidIdentity("STAR is reserved for namespace selection.")
    if value.count(".") > 1:
        raise InvalidIdentity("At most one TLDx separator is allowed.")
    if any(a in SYMBOLS and b in SYMBOLS for a, b in zip(value, value[1:])):
        raise InvalidIdentity("Adjacent symbols are not allowed.")

    if "." in value:
        base, tldx = value.split(".", 1)
    else:
        base, tldx = value, None
    if len(base) > MAX_BASE_LENGTH:
        raise InvalidIdentity(f"Base List Number must contain no more than {MAX_BASE_LENGTH} characters.")
    if base and not any(ch.isdigit() for ch in base):
        raise InvalidIdentity("Base List Number must contain a digit.")
    return ParsedIdentity(country_code=country, base=base, tldx=tldx, is_global=is_global)
