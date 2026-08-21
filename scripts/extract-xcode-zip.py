#!/usr/bin/env python3
"""Extract Xcode zip; normalize Windows backslash entry names."""
import os
import sys
import zipfile


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <zip> <dest>", file=sys.stderr)
        return 2
    zip_path, dest = sys.argv[1], sys.argv[2]
    os.makedirs(dest, exist_ok=True)
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            name = info.filename.replace("\\", "/")
            if not name or name.endswith("/"):
                continue
            out = os.path.join(dest, name)
            parent = os.path.dirname(out)
            if parent:
                os.makedirs(parent, exist_ok=True)
            with zf.open(info) as src, open(out, "wb") as dst:
                dst.write(src.read())
    print(f"extracted {zip_path} -> {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
