#!/bin/sh
# fleetreeve.accounts.authorized_keys: the title is the account's login name.
#
# Called as `authorized_keys.sh check` and `authorized_keys.sh apply`. check
# prints one line per difference and nothing when the keys are as declared;
# it changes nothing.
#
# A home directory belongs to its account, which can put a symbolic link
# anywhere in it at any moment. Root must therefore never write there: a
# link from .ssh to /root/.ssh would turn "write alice's keys" into "let
# alice log in as root". Everything below that touches the home directory
# runs as the account itself, where a link can only lead to what the
# account could reach anyway.
set -eu
user=$FLEETREEVE_TITLE
keys=${FLEETREEVE_PARAM_KEYS:-}

case $user in
    ''|-*|*[!A-Za-z0-9._-]*) echo "not a login name: $user" >&2; exit 2 ;;
esac
[ -n "$keys" ] || { echo "keys is empty; leave the resource out to leave the account's keys alone" >&2; exit 2; }

# One key per line, exactly as the file should read.
want=$(printf '%s\n' "$keys" | sed '/^[[:space:]]*$/d')

# Not there yet: on a first run the account is created just before this,
# and a dry run comes before even that.
entry=$(getent passwd "$user" || true)
if [ -z "$entry" ]; then
    case $1 in
    check) echo "keys: none (no such account yet) -> $(printf '%s\n' "$want" | grep -c .) key(s)"; exit 0 ;;
    *) echo "there is no account $user" >&2; exit 1 ;;
    esac
fi
home=$(printf '%s\n' "$entry" | cut -d: -f6)
case $home in
    /*) ;;
    *) echo "$user has no home directory" >&2; exit 1 ;;
esac
[ "$(printf '%s\n' "$entry" | cut -d: -f3)" != 0 ] || { echo "$user is root: manage root's keys yourself" >&2; exit 2; }

command -v runuser >/dev/null 2>&1 || { echo "runuser is not installed (package util-linux)" >&2; exit 1; }

# Run a shell snippet as the account, in its home directory. The home
# directory arrives as $1, so nothing of ours is pasted into the snippet.
as_user() { runuser -u "$user" -- /bin/sh -c "cd \"\$1\" 2>/dev/null || exit 9; $1" sh "$home"; }

# What is there now, seen by the account itself: "<kind and mode of .ssh>",
# "<kind and mode of the file>", then the file's content.
look() {
    as_user '
        stat -c "%F %a %U" .ssh 2>/dev/null || echo absent
        stat -c "%F %a %U" .ssh/authorized_keys 2>/dev/null || echo absent
        [ -f .ssh/authorized_keys ] && [ ! -L .ssh/authorized_keys ] && [ ! -L .ssh ] && cat .ssh/authorized_keys || true
    '
}

case $1 in
check)
    seen=$(look) || { echo "home: $home is missing or closed to $user -> usable"; exit 0; }
    dir=$(printf '%s\n' "$seen" | sed -n 1p)
    file=$(printf '%s\n' "$seen" | sed -n 2p)
    have=$(printf '%s\n' "$seen" | sed '1,2d')
    [ "$dir" = "directory 700 $user" ] || echo ".ssh: $dir -> directory 700 $user"
    [ "$file" = "regular file 600 $user" ] || [ "$file" = "regular empty file 600 $user" ] || echo "authorized_keys: $file -> regular file 600 $user"
    if [ "$have" != "$want" ]; then
        n_have=$(printf '%s\n' "$have" | grep -c . || true)
        n_want=$(printf '%s\n' "$want" | grep -c . || true)
        add=$(printf '%s\n' "$want" | grep -c -v -x -F -e "$have" || true)
        [ -n "$have" ] || add=$n_want
        echo "keys: $n_have -> $n_want ($add to add; the rest removed or reordered)"
    fi
    ;;
apply)
    # All of it as the account. A .ssh or authorized_keys that is a link
    # (or anything but what it should be) is replaced, not followed.
    # shellcheck disable=SC2016  # the snippet is expanded by the account's shell, not here
    printf '%s\n' "$want" | as_user '
        set -e
        umask 077
        if [ -L .ssh ] || { [ -e .ssh ] && [ ! -d .ssh ]; }; then rm -f .ssh; fi
        [ -d .ssh ] || mkdir .ssh
        chmod 700 .ssh
        if [ -d .ssh/authorized_keys ] && [ ! -L .ssh/authorized_keys ]; then
            echo ".ssh/authorized_keys is a directory" >&2; exit 1
        fi
        tmp=$(mktemp .ssh/.fleetreeve-XXXXXX)
        cat > "$tmp"
        chmod 600 "$tmp"
        if [ -L .ssh/authorized_keys ]; then rm -f .ssh/authorized_keys; fi
        mv -f "$tmp" .ssh/authorized_keys
        # With SELinux, sshd only reads keys that carry the right label.
        if command -v restorecon >/dev/null 2>&1; then restorecon -R .ssh 2>/dev/null || true; fi
    ' || { rc=$?; [ $rc != 9 ] || echo "$home is missing or closed to $user" >&2; exit 1; }
    ;;
*)
    echo "unknown operation: $1" >&2
    exit 2
    ;;
esac
