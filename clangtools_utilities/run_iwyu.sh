#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# wrapper for iwyu_tool (with a hack to ensure .icc files are completely ignored!)
iwyu_tool.py -j 8 -p . "$@"  -- --mapping_file=$DIR/IWYUMu2e.imp | grep -v -e .icc