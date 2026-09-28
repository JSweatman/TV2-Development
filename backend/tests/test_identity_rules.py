import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from identity_rules import parse_identity, parse_prefix, InvalidIdentity


class IdentityRulesTests(unittest.TestCase):
    def test_default_country_matches_explicit_country(self):
        self.assertEqual(parse_identity("529"), parse_identity("1*529"))

    def test_explicit_country(self):
        self.assertEqual(parse_identity("91*529").country_code, "91")

    def test_global_code_sets_country_null(self):
        result = parse_identity("*445551212")
        self.assertIsNone(result.country_code)
        self.assertTrue(result.is_global)

    def test_tldx_is_separate_from_base(self):
        result = parse_identity("529.411")
        self.assertEqual(result.base, "529")
        self.assertEqual(result.tldx, "411")

    def test_permitted_base_symbols(self):
        self.assertEqual(parse_identity("12@34/56-78#90").base, "12@34/56-78#90")

    def test_base_only_length_limit(self):
        base = "123456789012345"
        # Explicit country and a long TLDx do not consume the 15-character base allowance.
        result = parse_identity(f"999*{base}.123456789012345")
        self.assertEqual(len(result.base), 15)
        with self.assertRaises(InvalidIdentity):
            parse_identity("1234567890123456")

    def test_strict_parser_rejects_incomplete_or_invalid_values(self):
        for value in (
            "", "*", "1*", "529.", "52##9", "52..9", "529A", "529 ",
            "1**529", "abc*529", "529@", "12.-3",
        ):
            with self.subTest(value=value), self.assertRaises(InvalidIdentity):
                parse_identity(value)

    def test_prefix_parser_accepts_transitional_trailing_symbol(self):
        self.assertEqual(parse_prefix("700@").base, "700@")
        p = parse_prefix("529.")
        self.assertEqual(p.base, "529")
        self.assertEqual(p.tldx, "")

    def test_prefix_parser_allows_namespace_marker_before_base(self):
        self.assertEqual(parse_prefix("1*").base, "")
        self.assertIsNone(parse_prefix("*").country_code)

    def test_country_context_is_syntax_only(self):
        self.assertEqual(parse_identity("529", "12345").country_code, "12345")
        with self.assertRaises(InvalidIdentity):
            parse_identity("529", "USA")


if __name__ == "__main__":
    unittest.main()
