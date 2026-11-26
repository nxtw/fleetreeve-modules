# fleetreeve.docker

Docker Engine from Docker's own package repository, with `daemon.json`
written from data and checked by Docker before it goes live. For the Red
Hat family (CentOS Stream, RHEL, Rocky, Alma, Fedora) and for Debian and
Ubuntu.

```yaml
# site.yaml
include:
  - module: fleetreeve.docker
    when: contains "docker" .host.groups     # only hosts in the group "docker"
```

```yaml
# data/groups/docker.yaml  (optional: the defaults give a working Docker)
docker_daemon:
  live-restore: true
  registry-mirrors: ["https://mirror.example.com"]
docker_users: [deploy]
```

| | |
| --- | --- |
| role `main` | Docker's repository and signing key, the packages, `/etc/docker/daemon.json`, the `docker` service running and enabled, and the accounts in `docker_users` in the `docker` group |

The module has no types.

## Variables

| | default | |
| --- | --- | --- |
| `docker_repo` | `true` | set up Docker's package repository. `false` when the packages come from a repository you provide yourself |
| `docker_repo_url` | `https://download.docker.com/linux` | a mirror of Docker's repository, if you have one. It must have the same layout |
| `docker_packages` | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` | what is installed. The first one is the package that brings `dockerd` |
| `docker_daemon_baseline` | log rotation, see below | settings for `daemon.json` that apply unless `docker_daemon` sets the same key |
| `docker_daemon` | `{}` | your settings for `daemon.json`, as they appear in [Docker's documentation](https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file) |
| `docker_restart` | `true` | restart Docker when `daemon.json` changes |
| `docker_users` | `[]` | accounts that may use Docker without sudo. Read the warning below |

## daemon.json

The file is the baseline with your settings on top:

```yaml
docker_daemon_baseline:
  log-driver: json-file
  log-opts: {max-size: 10m, max-file: "3"}
```

That baseline exists because Docker's own default keeps every container's
output for ever, in a file that grows until the disk is full. With it a
container keeps at most three files of 10 MB.

- A key in `docker_daemon` replaces the baseline's key of the same name
  whole: giving `log-opts` yourself means giving all of it.
- To drop the baseline altogether, set `docker_daemon_baseline: {}`.
- Values can be strings, numbers, `true`/`false`, lists and maps, nested
  as Docker expects them. Write numbers that Docker wants as text in
  quotes, as with `max-file` above.
- Before the file replaces the old one, `dockerd --validate` reads it. A
  setting Docker does not know, or a value it does not accept, fails the
  run with Docker's own message and leaves the running configuration
  alone.

**A change restarts Docker, which stops the containers on the host.**
They come back only if they have a restart policy. Two ways around that:

- `live-restore: true` in `docker_daemon` keeps containers running while
  the daemon restarts (not with swarm mode);
- `docker_restart: false` writes the file and leaves the daemon alone;
  the change takes effect when you restart Docker yourself.

## Things to know

- **Being in the `docker` group is being root on the host.** Anyone who
  can talk to Docker can start a container that mounts the host's
  filesystem. List in `docker_users` only accounts you would give sudo.
- Taking a name out of `docker_users` does not take the account out of
  the group; do that yourself (`gpasswd -d <name> docker`). An account
  that is logged in sees its new group at its next login.
- With [`fleetreeve.accounts`](../fleetreeve.accounts), which manages the
  whole list of an account's groups, put `docker` in that account's
  `groups` there instead of using `docker_users`, or the two will undo
  each other's work.
- **The key that signs Docker's packages comes with this module**
  (`templates/docker-rpm.asc`, `templates/docker-deb.asc`), so a host
  verifies what it installs against a key it did not have to download.
  Their fingerprints, to compare with
  [Docker's installation pages](https://docs.docker.com/engine/install/):
  `060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35` (rpm) and
  `9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88` (deb). Should
  Docker ever replace a key, this module needs a new version.
- Docker is installed at the newest version when the module first runs,
  and not upgraded after that; upgrade it with your package manager when
  you choose to, since that restarts Docker too.
- Docker writes its own firewall rules. A port a container publishes is
  reachable from outside whatever firewalld's zones say; publish on
  `127.0.0.1:` what should stay local.
- Removing the module from a host's manifest removes what fleetreeve
  created there, by its usual rule. Images, containers and volumes in
  `/var/lib/docker` are left.

Tested by applying it in containers of CentOS Stream 9 and Debian 12:
installation, a container run, a change of `daemon.json` with nested
settings, a refused setting, and both ways of handling a restart. The
other distributions named above use the same two code paths but were not
run. Not tried on a host that also has podman.
