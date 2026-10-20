import unittest

from check_core_coverage import core_line_coverage, meets_floor


class CoreCoverageTests(unittest.TestCase):
    def test_counts_only_executable_sweepdeck_core_source_lines(self):
        report = {
            "data": [{
                "files": [
                    {"filename": "/project/Sources/SweepdeckCore/Scanner.swift",
                     "summary": {"lines": {"covered": 85, "count": 100}}},
                    {"filename": "/project/Sources/Sweepdeck/ExplorerView.swift",
                     "summary": {"lines": {"covered": 0, "count": 100}}},
                    {"filename": "/project/Tests/SweepdeckCoreTests/ScannerTests.swift",
                     "summary": {"lines": {"covered": 100, "count": 100}}},
                ]
            }]
        }

        self.assertEqual(core_line_coverage(report), (85, 100))

    def test_coverage_floor_uses_all_executable_lines(self):
        self.assertTrue(meets_floor(85, 100, 80))
        self.assertFalse(meets_floor(79, 100, 80))

    def test_report_without_core_source_lines_is_rejected(self):
        with self.assertRaises(ValueError):
            core_line_coverage({"data": [{"files": []}]})


if __name__ == "__main__":
    unittest.main()
