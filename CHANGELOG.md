# Changelog

What changed in each tagged version of this repository, per module.

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
