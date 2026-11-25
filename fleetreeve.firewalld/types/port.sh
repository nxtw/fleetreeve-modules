#!/bin/sh
# fleetreeve.firewalld.port: the title is <port>/<protocol>, e.g. 8080/tcp.
#
# Called as `port.sh check` and `port.sh apply`. check prints one line per
# difference and nothing when the port is as declared; it changes nothing.
set -eu
port=$FLEETREEVE_TITLE
want=${FLEETREEVE_PARAM_ENSURE:-open}
zone=${FLEETREEVE_PARAM_ZONE:+--zone=$FLEETREEVE_PARAM_ZONE}

case $want in open|closed) ;; *) echo "ensure must be open or closed, not $want" >&2; exit 2 ;; esac
case $port in */tcp|*/udp|*/sctp|*/dccp) ;; *) echo "the title must be <port>/<protocol>, like 8080/tcp; got $port" >&2; exit 2 ;; esac

# Is the port open? $1 is --permanent or empty (the running firewall).
# Before firewalld is installed or started the answer is "closed".
is_open() { firewall-cmd $1 $zone --query-port="$port" >/dev/null 2>&1; }
state() { if is_open "$1"; then echo open; else echo closed; fi; }

case $1 in
check)
    [ "$(state --permanent)" = "$want" ] || echo "permanent: $(state --permanent) -> $want"
    [ "$(state '')" = "$want" ] || echo "running: $(state '') -> $want"
    ;;
apply)
    verb=--add-port
    [ "$want" = open ] || verb=--remove-port
    [ "$(state --permanent)" = "$want" ] || firewall-cmd --permanent $zone $verb="$port" >/dev/null
    [ "$(state '')" = "$want" ] || firewall-cmd $zone $verb="$port" >/dev/null
    ;;
*)
    echo "unknown operation: $1" >&2
    exit 2
    ;;
esac
