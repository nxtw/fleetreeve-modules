#!/bin/sh
# fleetreeve.docker.project: the title is the Compose project's name.
#
# Called as `project.sh check`, `apply` and `refresh`. check prints one line
# per difference and nothing when the project is as its compose file says;
# it changes nothing.
#
# "As the compose file says" is, per service: a container exists, it was
# made from the service as the file now describes it (Compose keeps a hash
# of that on the container), and it is running - or it ended by itself
# with success, as a job does. Containers of services that left the file
# are differences too.
set -eu
name=$FLEETREEVE_TITLE
ensure=${FLEETREEVE_PARAM_ENSURE:-present}
dir=${FLEETREEVE_PARAM_DIR:-}

# What Compose accepts as a project name.
case $name in
    ''|[!a-z0-9]*|*[!a-z0-9_-]*) echo "not a Compose project name (lower-case letters, digits, - and _; starting with a letter or digit): $name" >&2; exit 2 ;;
esac
case $ensure in present|absent) ;; *) echo "ensure must be present or absent, not $ensure" >&2; exit 2 ;; esac
case $dir in /*) ;; *) echo "dir must be a full path, not '$dir'" >&2; exit 2 ;; esac

# Not there yet: on a first run Docker is installed just before this, and
# a dry run comes before even that.
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    case $1 in
    check) [ "$ensure" = absent ] || echo "project: unknown (Docker is not installed yet) -> up"; exit 0 ;;
    *) echo "docker compose is not installed" >&2; exit 1 ;;
    esac
fi
if ! docker info >/dev/null 2>&1; then
    case $1 in
    check) [ "$ensure" = absent ] || echo "project: unknown (Docker is not running) -> up"; exit 0 ;;
    *) echo "Docker is not running" >&2; exit 1 ;;
    esac
fi

# The project's containers: "<service> <config hash> <state> <exit code>".
have() {
    ids=$(docker ps -aq --filter "label=com.docker.compose.project=$name")
    [ -n "$ids" ] || return 0
    # shellcheck disable=SC2086,SC2016  # the ids are separate words; the braces are docker's
    docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}} {{index .Config.Labels "com.docker.compose.config-hash"}} {{.State.Status}} {{.State.ExitCode}}' $ids
}

if [ "$ensure" = absent ]; then
    case $1 in
    check)
        n=$(have | grep -c . || true)
        [ "$n" = 0 ] || echo "project: $n container(s) -> removed"
        ;;
    apply)
        # By name, so it works whether or not the compose file is still there.
        docker compose -p "$name" down --remove-orphans >/dev/null
        ;;
    refresh) ;;
    esac
    exit 0
fi

file=
for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
    if [ -f "$dir/$f" ]; then file=$dir/$f; break; fi
done
if [ -z "$file" ]; then
    case $1 in
    check) echo "project: absent (no compose file in $dir yet) -> up"; exit 0 ;;
    *) echo "there is no compose.yaml in $dir" >&2; exit 1 ;;
    esac
fi
compose() { docker compose -p "$name" --project-directory "$dir" -f "$file" "$@"; }

case $1 in
check)
    # "<service> <hash>" for every service of the file, as it now reads.
    want=$(compose config --hash '*' 2>&1) || { echo "the compose file is not valid: $(printf '%s\n' "$want" | tail -1)" >&2; exit 1; }
    now=$(have)
    printf '%s\n' "$want" | while read -r service hash; do
        [ -n "$service" ] || continue
        # Several containers of one service (replicas): any one that is
        # not right makes the service not right.
        seen=$(printf '%s\n' "$now" | awk -v s="$service" '$1 == s')
        if [ -z "$seen" ]; then
            echo "service $service: absent -> running"
        elif printf '%s\n' "$seen" | awk -v h="$hash" '$2 != h { found = 1 } END { exit !found }'; then
            echo "service $service: changed in the compose file -> recreated"
        else
            bad=$(printf '%s\n' "$seen" | awk '!($3 == "running" || ($3 == "exited" && $4 == 0)) { print $3 ($3 == "exited" ? " with status " $4 : ""); exit }')
            [ -z "$bad" ] || echo "service $service: $bad -> running"
        fi
    done
    printf '%s\n' "$now" | awk '{ print $1 }' | sort -u | while read -r service; do
        [ -n "$service" ] || continue
        printf '%s\n' "$want" | awk -v s="$service" '$1 == s { found = 1 } END { exit !found }' || echo "service $service: no longer in the compose file -> removed"
    done
    ;;
apply|refresh)
    # Idempotent: creates what is missing, recreates what changed, starts
    # what stopped, removes what left the file - and nothing else.
    out=$(compose up -d --remove-orphans --quiet-pull 2>&1) || { printf '%s\n' "$out" | tail -5 >&2; exit 1; }
    ;;
*)
    echo "unknown operation: $1" >&2
    exit 2
    ;;
esac
