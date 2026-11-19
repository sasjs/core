"""Static guard checks; the SAS integration tests require a Viya runtime."""
import pathlib
import re
import unittest


SOURCE = pathlib.Path(__file__).resolve().parents[2] / "viya/mv_getfoldermembers.sas"


class HttpGuardTests(unittest.TestCase):
    def test_each_response_is_checked_before_json_is_opened(self):
        source = SOURCE.read_text()
        requests = re.findall(
            r"proc http\b.*?\brun\s*;(.*?)(?=\blibname\s+&libref[12]\s+JSON)",
            source,
            flags=re.IGNORECASE | re.DOTALL,
        )
        self.assertEqual(len(requests), 3, "expected root, lookup and members requests")
        for stage, response in zip(("root", "lookup", "members"), requests):
            with self.subTest(stage=stage):
                self.assertRegex(
                    response.lower(),
                    r"%mp_abort\s*\(\s*iftrue\s*=\s*\(\s*&sys_prochttp_status_code\s+ne\s+200\s*\)",
                )
                self.assertIn("&sys_prochttp_status_phrase", response.lower())


if __name__ == "__main__":
    unittest.main()
