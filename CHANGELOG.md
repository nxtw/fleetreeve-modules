# Changelog

What changed in each tagged version of this repository, per module.

## v0.4.1

- `fleetreeve.accounts` 0.2.1: the process that writes an account's keys
  as that account is now started with an empty environment and in a
  session of its own. In 0.2.0 it inherited the environment of the
  fleetreeve agent, which the account could read while the process ran -
  including a token, where the agent was started with one in its
  environment - and, when fleetreeve was run from a shell, root's
  terminal. Nothing to do but update; skip 0.2.0.

## v0.4.0

- `fleetreeve.accounts` 0.2.0: **the SSH keys of an account are now
  written by a process running as that account, not by root.** An account
  owns its home directory and could, with a symbolic link placed at the
  right moment, make root write the keys somewhere else - into root's own
  `authorized_keys`, for instance. That needed an account on the host, no
  sudo, and winning a race; it is closed. New type
  `fleetreeve.accounts.authorized_keys`, which the `user` type uses.

  *What you have to do, if you applied 0.1.0 to hosts:* in 0.1.0 `.ssh`
  and `authorized_keys` were `file` resources. Once they are no longer in
  the manifest, fleetreeve removes the ones it created - after the new
  type has written the keys, so the accounts would be without keys until
  the run after. Avoid that by telling fleetreeve to stop tracking the old
  resources before the first run with the new module, for each account:

  ```sh
  fleetreeve state rm site.yaml 'file[/home/alice/.ssh/authorized_keys]' 'file[/home/alice/.ssh]'
  ```

  or by making that first run with `-no-prune` (for hosts that pull:
  `-no-prune` on the server for one interval). `fleetreeve state site.yaml`
  shows what is tracked. Nothing changes in your data. If you never
  applied 0.1.0, there is nothing to do.

  If you have 0.1.0 on hosts with accounts that have no sudo, update soon.

## v0.3.0

Three new modules.

- `fleetreeve.sshd` 0.1.0: the OpenSSH server, with its settings in a
  drop-in that sshd checks before it goes live, and the
  `fleetreeve.sshd.config` type for further drop-ins such as `Match`
  blocks.
- `fleetreeve.accounts` 0.1.0: people's accounts from data, with their
  SSH keys, groups and sudo rights; the `fleetreeve.accounts.user` type.
- `fleetreeve.selinux` 0.1.0: the types `fleetreeve.selinux.boolean`,
  `fleetreeve.selinux.port` and `fleetreeve.selinux.fcontext`, and a role
  that declares them from data.

## v0.2.0

- `fleetreeve.nginx` 0.2.0: **a site's web root is now owned by root**
  instead of by the nginx user, so that a compromised nginx process cannot
  rewrite the content it serves. nginx still reads it (mode 0755).

  *What you have to do:* on the first run after updating, the owner of
  every existing web root changes to root; files inside are left as they
  are. If something writes into a web root as the nginx user, it will no
  longer be able to create files there: declare that directory yourself
  with the owner it needs.

## v0.1.0

The first version: the three modules that until now only shipped as
examples with fleetreeve.

- `fleetreeve.nginx` 0.1.0: nginx, and the `fleetreeve.nginx.vhost` type.
- `fleetreeve.firewalld` 0.1.0: firewalld, and the
  `fleetreeve.firewalld.port` type.
- `fleetreeve.gitlab_runner` 0.1.0: GitLab Runner, with runners written
  from data or registered by the host through the
  `fleetreeve.gitlab_runner.runner` type.
