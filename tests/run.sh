#!/bin/sh
# Checks every module in this repository with the fleetreeve on $PATH (or
# $FLEETREEVE): each must load, compile in a manifest that uses all its
# roles and types, and install into a project the way a user installs it.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
fleetreeve=${FLEETREEVE:-fleetreeve}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"$fleetreeve" version

modules=$(cd "$repo" && ls -d *.*/ | tr -d /)
test -n "$modules" || { echo "no modules found in $repo" >&2; exit 1; }

echo
echo "== every module has what a module needs"
for m in $modules; do
    for f in module.yaml README.md; do
        test -f "$repo/$m/$f" || { echo "$m: $f is missing" >&2; exit 1; }
    done
    grep -q "^name: $m\$" "$repo/$m/module.yaml" || { echo "$m: module.yaml does not say 'name: $m'" >&2; exit 1; }
    grep -q "$m" "$repo/README.md" || { echo "$m: not listed in README.md" >&2; exit 1; }
    grep -q "module: $m\$" "$repo/tests/site.yaml" || { echo "$m: not used in tests/site.yaml" >&2; exit 1; }
    echo "$m: ok"
done

echo
echo "== the test manifest compiles with all of them"
FLEETREEVE_MODULES="$repo" "$fleetreeve" validate -facts "$repo/tests/centos9.facts.json" "$repo/tests/site.yaml"

echo
echo "== each installs into a project, and verifies"
mkdir "$work/project"
cd "$work/project"
for m in $modules; do
    "$fleetreeve" module add "$repo/$m" | head -1
done
"$fleetreeve" module verify
"$fleetreeve" module list | grep -E '^fleetreeve\.'

echo
echo "All modules pass."
