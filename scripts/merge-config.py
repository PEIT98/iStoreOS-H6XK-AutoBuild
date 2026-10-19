#!/usr/bin/env python3
"""Merge explicit H6XK overrides into the device config without duplicate Kconfig keys."""
import re
import sys
from pathlib import Path

ASSIGNMENT = re.compile(r"^(CONFIG_[A-Za-z0-9_]+)=")
DISABLED = re.compile(r"^# (CONFIG_[A-Za-z0-9_]+) is not set$")


def key(line):
    match = ASSIGNMENT.match(line) or DISABLED.match(line)
    return match.group(1) if match else None


def merge(base, overrides):
    patch = overrides.splitlines()
    keys = [item for line in patch if (item := key(line))]
    if len(keys) != len(set(keys)):
        raise ValueError("Duplicate Kconfig key in feature overrides")
    replaced = set(keys)
    lines = [line for line in base.splitlines() if key(line) not in replaced]
    return "\n".join([*lines, "", "# H6XK feature overrides", *patch, ""])


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("Usage: merge-config.py BASE OVERRIDES OUTPUT")
    source, features, output = map(Path, sys.argv[1:])
    output.write_text(merge(source.read_text(), features.read_text()))
