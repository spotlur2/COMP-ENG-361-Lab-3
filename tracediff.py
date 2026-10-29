#!/usr/bin/env python3
"""Top-level wrapper for tools/tracediff.py so `python3 tracediff.py <yours> <golden>` works directly."""
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.join(SCRIPT_DIR, "tools")
if os.path.isdir(TOOLS_DIR) and TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from tracediff import main

if __name__ == "__main__":
    main()
