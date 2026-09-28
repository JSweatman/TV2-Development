import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from country_policy import CountryPolicy, CountryPolicyCatalog


def test_country_policy_is_optional_and_external_to_parser():
    catalog = CountryPolicyCatalog({
        "1": CountryPolicy(country_code="1", base_max_length=10, initial_language="en")
    })
    assert catalog.get("1").base_max_length == 10
    assert catalog.get("91") is None
