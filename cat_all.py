#!/usr/bin/env python3
import os

def cat_files(base_dir="."):
    count = 1
    for root, dirs, files in os.walk(base_dir):
        # Skip 'venv' directories
        # if "workloads" in dirs:
            # dirs.remove("workloads")
        if "src" in dirs:
            dirs.remove("src")
        if "venv" in dirs:
            dirs.remove("venv")
        if "data" in dirs:
            dirs.remove("data")
        if "cat_all.py" in files:
            files.remove("cat_all.py")
        if "requirements.txt" in files:
            files.remove("requirements.txt")

        for file in files:
            path = os.path.join(root, file)
            print(f"[{count}] {path}")
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    print(f.read())
            except Exception as e:
                print(f"--- Error reading {path}: {e} ---")
            print()  # blank line between files
            count += 1

if __name__ == "__main__":
    cat_files()
