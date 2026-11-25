#!/bin/sh
# fleetreeve.gitlab_runner.runner: the title is the runner's name on this host.
#
# Registering is `gitlab-runner register` with the runner's authentication
# token. That token is either given (token), or obtained by creating the
# runner in GitLab through its API (access_token). What fleetreeve obtained is
# kept in /etc/gitlab-runner/fleetreeve/, readable by root only:
#   <name>.token     the authentication token; a second line "created"
#                    when fleetreeve created the runner in GitLab
#   <name>.settings  a checksum of the settings it was registered with
#
# check changes nothing and never contacts GitLab. No token is ever
# printed or passed on a command line.
set -eu
umask 077

name=$FLEETREEVE_TITLE
want=${FLEETREEVE_PARAM_ENSURE:-present}
url=${FLEETREEVE_PARAM_URL%/}
token=${FLEETREEVE_PARAM_TOKEN:-}
pat=${FLEETREEVE_PARAM_ACCESS_TOKEN:-}
executor=${FLEETREEVE_PARAM_EXECUTOR:-shell}
config=${FLEETREEVE_GITLAB_RUNNER_CONFIG:-/etc/gitlab-runner/config.toml}
dir=${FLEETREEVE_GITLAB_RUNNER_STATE:-/etc/gitlab-runner/fleetreeve}
key=$(printf %s "$name" | tr -c 'A-Za-z0-9._-' '_')
token_file=$dir/$key.token
settings_file=$dir/$key.settings
nl='
'

die() { echo "$*" >&2; exit 2; }
case $want in present|absent) ;; *) die "ensure must be present or absent, not $want" ;; esac
case $name in *'"'*|*"$nl"*|'') die "the title is the runner's name: no quotes or line breaks" ;; esac
case $url in http://*|https://*) ;; *) die "url must start with https:// (or http://), got $url" ;; esac

registered() { [ -f "$config" ] && grep -qF "name = \"$name\"" "$config"; }
saved_token() { [ -f "$token_file" ] && sed -n 1p "$token_file" || true; }
created_here() { [ -f "$token_file" ] && [ "$(sed -n 2p "$token_file")" = created ]; }

# Everything `gitlab-runner register` is given. A change means registering again.
settings() {
    printf '%s\n' "$url" "$executor" "${FLEETREEVE_PARAM_LIMIT:-0}" "${FLEETREEVE_PARAM_ENVIRONMENT:-}" \
        "${FLEETREEVE_PARAM_DOCKER_IMAGE:-}" "${FLEETREEVE_PARAM_DOCKER_PRIVILEGED:-}" "${FLEETREEVE_PARAM_DOCKER_VOLUMES:-}" \
        "${FLEETREEVE_PARAM_DOCKER_PULL_POLICY:-}" "${FLEETREEVE_PARAM_DOCKER_HOST:-}" "${FLEETREEVE_PARAM_TLS_CA_FILE:-}" \
        "${FLEETREEVE_PARAM_REGISTER_ARGS:-}" | sha256sum | cut -c1-12
}

# api METHOD PATH [name=value...]: call GitLab with the access token or,
# for a path taking the runner's own token, without. The reply's body is
# left in $body. Secrets go to curl on stdin, not on its command line.
api() {
    method=$1 path=$2; shift 2
    body=$(mktemp)
    {
        echo "request = \"$method\""
        echo "url = \"$url/api/v4$path\""
        [ -z "${FLEETREEVE_PARAM_TLS_CA_FILE:-}" ] || echo "cacert = \"$FLEETREEVE_PARAM_TLS_CA_FILE\""
        [ -z "$api_auth" ] || echo "header = \"PRIVATE-TOKEN: $api_auth\""
        for kv in "$@"; do echo "data-urlencode = \"$kv\""; done
    } | curl --silent --show-error --max-time 60 --output "$body" --write-out '%{http_code}' --config - > "$body.code" || {
        rm -f "$body" "$body.code"; die "could not reach $url"
    }
    code=$(cat "$body.code"); rm -f "$body.code"
}

create_in_gitlab() {
    [ -n "$pat" ] || die "give either token (a glrt-… token) or access_token (to create the runner in GitLab)"
    type=${FLEETREEVE_PARAM_RUNNER_TYPE:-instance_type}
    set -- "runner_type=$type" "description=$name" "run_untagged=${FLEETREEVE_PARAM_RUN_UNTAGGED:-true}" "locked=${FLEETREEVE_PARAM_LOCKED:-false}"
    case $type in
    instance_type) ;;
    group_type)   [ -n "${FLEETREEVE_PARAM_GROUP_ID:-}" ] || die "runner_type group_type needs group_id"; set -- "$@" "group_id=$FLEETREEVE_PARAM_GROUP_ID" ;;
    project_type) [ -n "${FLEETREEVE_PARAM_PROJECT_ID:-}" ] || die "runner_type project_type needs project_id"; set -- "$@" "project_id=$FLEETREEVE_PARAM_PROJECT_ID" ;;
    *) die "runner_type must be instance_type, group_type or project_type, not $type" ;;
    esac
    [ -z "${FLEETREEVE_PARAM_TAGS:-}" ] || set -- "$@" "tag_list=$(printf %s "$FLEETREEVE_PARAM_TAGS" | tr '\n' ',')"
    api_auth=$pat api POST /user/runners "$@"
    if [ "$code" != 201 ]; then
        msg=$(head -c 300 "$body"); rm -f "$body"
        die "GitLab refused to create the runner (HTTP $code): $msg"
    fi
    new=$(tr -d '\n' < "$body" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'); rm -f "$body"
    [ -n "$new" ] || die "GitLab created the runner but the reply held no token"
    mkdir -p "$dir"
    printf '%s\ncreated\n' "$new" > "$token_file"   # kept before anything else can fail
    token=$new
}

register() {
    set -- register --non-interactive --config "$config"
    [ "${FLEETREEVE_PARAM_LIMIT:-0}" = 0 ] || set -- "$@" --limit "$FLEETREEVE_PARAM_LIMIT"
    old_ifs=$IFS; IFS=$nl
    for e in ${FLEETREEVE_PARAM_ENVIRONMENT:-}; do set -- "$@" --env "$e"; done
    if [ "$executor" = docker ]; then
        set -- "$@" --docker-image "${FLEETREEVE_PARAM_DOCKER_IMAGE:-almalinux:9}"
        [ "${FLEETREEVE_PARAM_DOCKER_PRIVILEGED:-false}" != true ] || set -- "$@" --docker-privileged
        for v in ${FLEETREEVE_PARAM_DOCKER_VOLUMES:-}; do set -- "$@" --docker-volumes "$v"; done
        [ -z "${FLEETREEVE_PARAM_DOCKER_PULL_POLICY:-}" ] || set -- "$@" --docker-pull-policy "$FLEETREEVE_PARAM_DOCKER_PULL_POLICY"
        [ -z "${FLEETREEVE_PARAM_DOCKER_HOST:-}" ] || set -- "$@" --docker-host "$FLEETREEVE_PARAM_DOCKER_HOST"
    fi
    for a in ${FLEETREEVE_PARAM_REGISTER_ARGS:-}; do set -- "$@" "$a"; done
    IFS=$old_ifs
    [ -z "${FLEETREEVE_PARAM_TLS_CA_FILE:-}" ] || export CI_SERVER_TLS_CA_FILE="$FLEETREEVE_PARAM_TLS_CA_FILE"
    # URL, token, name and executor travel in the environment.
    out=$(CI_SERVER_URL=$url CI_SERVER_TOKEN=$token RUNNER_NAME=$name RUNNER_EXECUTOR=$executor gitlab-runner "$@" 2>&1) || {
        echo "gitlab-runner register failed:" >&2
        printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'ERROR|FATAL|PANIC|WARNING' | tail -4 >&2
        exit 1
    }
}

unregister() {
    gitlab-runner unregister --config "$config" --name "$name" >/dev/null 2>&1 || true
    ! registered || die "could not unregister $name"
}

case $1 in
check)
    if [ "$want" = absent ]; then
        if registered || [ -f "$token_file" ]; then
            if created_here; then echo "runner: registered -> unregistered and deleted in GitLab"; else echo "runner: registered -> unregistered"; fi
        fi
        exit 0
    fi
    have=$(saved_token)
    [ -n "$token" ] || [ -n "$have" ] || [ -n "$pat" ] || die "give either token (a glrt-… token) or access_token (to create the runner in GitLab)"
    if ! registered; then
        if [ -z "$token" ] && [ -z "$have" ]; then echo "runner: absent -> created in GitLab and registered"; else echo "runner: absent -> registered"; fi
        exit 0
    fi
    [ -z "$token" ] || [ "$token" = "$have" ] || echo "token: (another) -> (the one given)"
    was=$(cat "$settings_file" 2>/dev/null || echo unknown)
    [ "$was" = "$(settings)" ] || echo "settings: $was -> $(settings)"
    ;;
apply)
    command -v gitlab-runner >/dev/null || die "gitlab-runner is not installed"
    if [ "$want" = absent ]; then
        t=$(saved_token)
        ! registered || unregister
        if created_here && [ -n "$t" ]; then
            api_auth='' api DELETE /runners "token=$t"
            rm -f "$body"
            case $code in 204|403|404) ;; *) die "GitLab refused to delete the runner (HTTP $code)" ;; esac
        fi
        rm -f "$token_file" "$settings_file"
        exit 0
    fi
    mkdir -p "$dir"
    if [ -n "$token" ]; then
        [ "$token" = "$(saved_token)" ] || printf '%s\n' "$token" > "$token_file"
    else
        token=$(saved_token)
        [ -n "$token" ] || create_in_gitlab
    fi
    ! registered || unregister
    register
    settings > "$settings_file"
    ;;
*)
    die "unknown operation: $1"
    ;;
esac
