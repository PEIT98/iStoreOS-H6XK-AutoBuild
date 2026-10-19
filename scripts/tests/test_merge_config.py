#!/usr/bin/env python3
"""Verify feature overrides survive merging without duplicate Kconfig entries."""
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('merge_config', ROOT / 'scripts/merge-config.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MergeConfigTests(unittest.TestCase):
    def test_overrides_replace_both_enabled_and_disabled_values(self):
        base = 'CONFIG_PACKAGE_foo=y\n# CONFIG_PACKAGE_bar is not set\n'
        overrides = '# CONFIG_PACKAGE_foo is not set\nCONFIG_PACKAGE_bar=y\n'
        merged = module.merge(base, overrides)
        self.assertEqual(merged.count('CONFIG_PACKAGE_foo'), 1)
        self.assertEqual(merged.count('CONFIG_PACKAGE_bar'), 1)
        self.assertIn('# CONFIG_PACKAGE_foo is not set', merged)
        self.assertIn('CONFIG_PACKAGE_bar=y', merged)

    def test_current_repository_has_unique_selected_options(self):
        merged = module.merge((ROOT / '.config').read_text(),
                              (ROOT / 'h6xk-features.config').read_text())
        keys = [module.key(line) for line in merged.splitlines()]
        keys = [key for key in keys if key]
        self.assertEqual(len(keys), len(set(keys)))
        required = [line for line in (ROOT / 'required-packages.txt').read_text().splitlines()
                    if line.startswith('CONFIG_')]
        for item in required:
            self.assertIn(item + '=y', merged)


if __name__ == '__main__':
    unittest.main()
