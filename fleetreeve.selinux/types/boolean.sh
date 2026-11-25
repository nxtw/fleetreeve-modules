#!/bin/sh
# fleetreeve.selinux.boolean: the title is the boolean's name.
#
# Called as `boolean.sh check` and `boolean.sh apply`. check prints one
# line per difference and nothing when the boolean is as declared; it
# changes nothing.
set -eu
name=$FLEETREEVE_TITLE
case ${FLEETREEVE_PARAM_VALUE:-on} in
    on|true|1) want=on ;;
    off|false|0) want=off ;;
    *) echo "value must be on or off, not ${FLEETREEVE_PARAM_VALUE}" >&2; exit 2 ;;
esac
case $name in
    ''|*[!A-Za-z0-9_]*) echo "not the name of a boolean: $name" >&2; exit 2 ;;
esac

if ! command -v getsebool >/dev/null 2>&1 || ! getsebool "$name" >/dev/null 2>&1; then
    if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
        echo "SELinux has no boolean called $name here" >&2
    else
        echo "SELinux is not enabled on this host" >&2
    fi
    exit 1
fi

# The value in the running policy.
running() { getsebool "$name" | sed 's/.* --> //'; }

# The value the policy store gives it at the next boot. `semanage boolean
# -l` prints "name  (now , stored)  description"; where semanage is not
# installed yet, the running value is the best answer there is.
stored() {
    if command -v semanage >/dev/null 2>&1; then
        semanage boolean -l -n | awk -v n="$name" '$1 == n && !seen { v = $4; sub(/\)$/, "", v); print v; seen = 1 }'
    else
        running
    fi
}

case $1 in
check)
    now=$(running)
    [ "$now" = "$want" ] || echo "running: $now -> $want"
    kept=$(stored)
    [ "${kept:-$now}" = "$want" ] || echo "stored: ${kept:-$now} -> $want"
    ;;
apply)
    # -P sets both the running value and the stored one.
    setsebool -P "$name" "$want"
    ;;
*)
    echo "unknown operation: $1" >&2
    exit 2
    ;;
esac
