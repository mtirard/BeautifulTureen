#!/bin/sh
# Adds the paclet's Needs line at the head of each mirrored symbol page's
# Examples section. `wltext show` drops the ExampleInitialization cell
# (mtirard/wl-text#514); delete this script, and its calls in the Makefile and
# the pre-commit hook, once `show` projects that cell itself.
set -eu
dir=${1:?usage: add-example-init.sh <markdown-dir>}
needs='Needs["MaximilienTirard`HTMLPatterns`"]'
for f in "$dir"/ref/*.md; do
	grep -qF "$needs" "$f" && continue
	grep -qx '## Examples' "$f" || continue
	awk -v needs="$needs" '
		{ print }
		$0 == "## Examples" && !done { print ""; print "```wl"; print needs; print "```"; done = 1 }
	' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
