#!/bin/sh
# fleetreeve.selinux.port: the title is <port>/<protocol>, e.g. 8080/tcp,
# or a range, 8000-8010/tcp.
#
# Called as `port.sh check` and `port.sh apply`. check prints one line per
# difference and nothing when the port is as declared; it changes nothing.
set -eu
title=$FLEETREEVE_TITLE
type=${FLEETREEVE_PARAM_TYPE:-}
want=${FLEETREEVE_PARAM_ENSURE:-present}

case $want in present|absent) ;; *) echo "ensure must be present or absent, not $want" >&2; exit 2 ;; esac
case $title in
    */tcp|*/udp|*/sctp|*/dccp) ;;
    *) echo "the title must be <port>/<protocol>, like 8080/tcp; got $title" >&2; exit 2 ;;
esac
port=${title%/*}
proto=${title##*/}
case $port in
    ''|*[!0-9-]*|-*|*-|*-*-*) echo "not a port or a range of ports: $port" >&2; exit 2 ;;
esac
case $type in
    ''|*[!A-Za-z0-9_]*) echo "type must be a port type such as http_port_t; got '$type'" >&2; exit 2 ;;
esac

have_semanage() { command -v semanage >/dev/null 2>&1; }

# The type this exact port (or range) carries, from the list in $1:
# "" for the whole policy, -C for what was added on this host. Lines look
# like "http_port_t   tcp   80, 81, 443". Prints nothing when it has none.
labelled() {
    have_semanage || return 0
    semanage port -l -n ${1:+"$1"} | awk -v proto="$proto" -v port="$port" '
        $2 == proto && !seen {
            for (i = 3; i <= NF; i++) { p = $i; sub(/,$/, "", p); if (p == port && !seen) { print $1; seen = 1 } }
        }'
}

# Is it labelled with our type? A port can carry several types in the
# policy, so look for ours rather than at the first one found.
has_type() {
    have_semanage || return 1
    semanage port -l -n ${1:+"$1"} | awk -v proto="$proto" -v port="$port" -v type="$type" '
        $1 == type && $2 == proto {
            for (i = 3; i <= NF; i++) { p = $i; sub(/,$/, "", p); if (p == port) found = 1 }
        }
        END { exit !found }'
}

case $1 in
check)
    if [ "$want" = present ]; then
        if ! has_type ""; then
            was=$(labelled "")
            echo "type: ${was:-none} -> $type"
        fi
    else
        ! has_type -C || echo "type: $type -> removed"
    fi
    ;;
apply)
    have_semanage || { echo "semanage is not installed (package policycoreutils-python-utils)" >&2; exit 1; }
    if [ "$want" = present ]; then
        if ! has_type ""; then
            # -a adds a label; a port that already has one from the policy,
            # or from an earlier change here, has to be modified instead.
            semanage port -a -t "$type" -p "$proto" "$port" 2>/dev/null ||
                semanage port -m -t "$type" -p "$proto" "$port"
        fi
    else
        ! has_type -C || semanage port -d -t "$type" -p "$proto" "$port"
    fi
    ;;
*)
    echo "unknown operation: $1" >&2
    exit 2
    ;;
esac
