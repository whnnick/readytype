#!/usr/bin/env python3

import pathlib
import re
import subprocess
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
    r"/Users/(?!me(?:/|$)|user(?:/|$)|username(?:/|$)|Shared(?:/|$))[A-Za-z0-9._-]+/",
]))
EXCLUDED_DIRECTORIES = {".git", ".build", "dist"}
INTERNAL_FILENAMES = {"AGENTS.md", "CLAUDE.md", "context.log"}
INTERNAL_PATH_PARTS = {".agents", ".codex", ".media", ".thumbnails", ".waveform-cache"}


def tracked_internal_artifacts() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        check=True,
        capture_output=True,
    )
    paths = result.stdout.decode("utf-8").split("\0")
    return [
        path
        for path in paths
        if path
        and (
            pathlib.PurePosixPath(path).name in INTERNAL_FILENAMES
            or any(part in INTERNAL_PATH_PARTS for part in pathlib.PurePosixPath(path).parts)
        )
    ]


def main() -> int:
    matches: list[str] = []
    matches.extend(f"{path}: internal development artifact is tracked" for path in tracked_internal_artifacts())
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
