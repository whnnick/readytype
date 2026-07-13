#!/usr/bin/env python3

import pathlib
import re
import sys


PATTERN = re.compile("|".join([
    r"sk-[A-Za-z0-9_-]{10,}",
    r"api[_-]?key\s*=",
    r"API_KEY\s*=",
    "Authorization:" + r"\s*Bearer",
    r"BEGIN (RSA|OPENSSH|PRIVATE) KEY",
    r"xox[baprs]-",
    r"ghp_[A-Za-z0-9_]{20,}",
    "github_" + "pat_",
]))
EXCLUDED_DIRECTORIES = {".git", ".build", "dist"}


def main() -> int:
    matches: list[str] = []
    for path in pathlib.Path(".").rglob("*"):
        if not path.is_file() or any(part in EXCLUDED_DIRECTORIES for part in path.parts):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            if PATTERN.search(line):
                matches.append(f"{path}:{line_number}:{line}")

    if not matches:
        return 0

    print("Sensitive-information scan found matches. Review before release.", file=sys.stderr)
    print("\n".join(matches), file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
