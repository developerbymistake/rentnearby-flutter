#!/bin/sh
# Template fixture run (headless Chrome, same tool as the mock's gen/render.sh). Add --png for screenshots.
cd "$(dirname "$0")/../.." && python -I tool/quote_templates/run_fixtures.py "$@"
