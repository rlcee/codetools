#!/bin/bash

# wrapper for iwyu_tool (with a hack to ensure .icc files are completely ignored!)
iwyu_tool.py -j 8 -p . "$@"  -- --mapping_file=IWYUMu2e.imp | grep -v -e .icc