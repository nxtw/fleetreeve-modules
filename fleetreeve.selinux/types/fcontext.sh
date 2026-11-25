#!/bin/sh
# fleetreeve.selinux.fcontext: the title is a path, or a path pattern as
# semanage takes it, e.g. "/srv/www(/.*)?" for a directory and all in it.
#
# Called as `fcontext.sh check` and `fcontext.sh apply`. check prints one
# line per difference and nothing when all is as declared; it changes
# nothing.
set -eu
spec=$FLEETREEVE_TITLE
type=${FLEETREEVE_PARAM_TYPE:-}
want=${FLEETREEVE_PARAM_ENSURE:-present}
relabel=${FLEETREEVE_PARAM_RELABEL:-true}

case $want in present|absent) ;; *) echo "ensure must be present or absent, not $want" >&2; exit 2 ;; esac
case $spec in
    /*) ;;
    *) echo "the title must be an absolute path or path pattern; got $spec" >&2; exit 2 ;;
esac
case $spec in
    *[[:space:]]*) echo "a path pattern cannot contain white space: $spec" >&2; exit 2 ;;
esac
case $type in
    ''|*[!A-Za-z0-9_]*) echo "type must be a file type such as httpd_sys_content_t; got '$type'" >&2; exit 2 ;;
esac

# The directory or file the pattern is about: the pattern up to its first
# special character, without a trailing slash. "/srv/www(/.*)?" is about
# /srv/www. Labels are checked and corrected from there down.
base=$(printf '%s\n' "$spec" | sed 's/[][(|*?+^$\\].*//; s:/*$::')
[ -n "$base" ] || { echo "$spec would relabel the whole file system; give a pattern that starts with a directory" >&2; exit 2; }

have_semanage() { command -v semanage >/dev/null 2>&1; }

# The type the rule added on this host gives this pattern; nothing when
# there is no such rule. Lines look like
# "/srv/www(/.*)?   all files   system_u:object_r:httpd_sys_content_t:s0".
rule() {
    have_semanage || return 0
    semanage fcontext -l -C -n | awk -v spec="$spec" '
        $1 == spec && !seen { n = split($NF, c, ":"); if (n >= 3) print c[3]; seen = 1 }'
}

# How many existing files carry another label than the policy gives them.
mislabelled() {
    if [ "$relabel" = true ] && [ -e "$base" ] && command -v restorecon >/dev/null 2>&1; then
        restorecon -R -n -v "$base" 2>/dev/null | grep -c . || true
    else
        echo 0
    fi
}

case $1 in
check)
    have=$(rule)
    if [ "$want" = present ]; then
        [ "$have" = "$type" ] || echo "rule: ${have:-none} -> $type"
    else
        [ -z "$have" ] || echo "rule: $have -> removed"
    fi
    n=$(mislabelled)
    [ "$n" = 0 ] || echo "labels: $n to correct under $base -> correct"
    ;;
apply)
    have_semanage || { echo "semanage is not installed (package policycoreutils-python-utils)" >&2; exit 1; }
    have=$(rule)
    if [ "$want" = present ]; then
        if [ -z "$have" ]; then
            semanage fcontext -a -t "$type" "$spec"
        elif [ "$have" != "$type" ]; then
            semanage fcontext -m -t "$type" "$spec"
        fi
    elif [ -n "$have" ]; then
        semanage fcontext -d "$spec"
    fi
    if [ "$relabel" = true ] && [ -e "$base" ]; then
        restorecon -R "$base"
    fi
    ;;
*)
    echo "unknown operation: $1" >&2
    exit 2
    ;;
esac
