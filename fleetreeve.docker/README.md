# fleetreeve.docker

Docker Engine from Docker's own package repository, with `daemon.json`
written from data and checked by Docker before it goes live, and Docker
Compose projects as resources. For the Red Hat family (CentOS Stream,
RHEL, Rocky, Alma, Fedora) and for Debian and Ubuntu.

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
| role `main` | Docker's repository and signing key, the packages, `/etc/docker/daemon.json`, the `docker` service running and enabled, the accounts in `docker_users` in the `docker` group, and the Compose projects in `docker_compose` |
| type `fleetreeve.docker.compose` | a Compose project from a compose file in your configuration, titled by the project's name: the file, its `.env`, and the project kept up |
| type `fleetreeve.docker.project` | only the "kept up" part, for a compose file that something else puts on the host; parameter `dir` |

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
| `docker_compose` | `[]` | Compose projects to run; see [Compose projects](#compose-projects) |
| `docker_compose_dir` | `/opt/compose` | where projects get their directory, one each |

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

## Compose projects

From data, for the hosts the data applies to:

```yaml
# data/groups/docker.yaml
docker_compose:
  - name: whoami
    env:
      WHO_PORT: "8080"
    content: |
      services:
        web:
          image: traefik/whoami
          ports: ["127.0.0.1:${WHO_PORT}:80"]
          restart: unless-stopped
  - name: old-thing
    ensure: absent                  # stop it and remove it
```

Or as a resource in a manifest, next to what belongs with it:

```yaml
resources:
  - fleetreeve.docker.compose: whoami
    content: |
      services:
        web:
          image: traefik/whoami
    require: service[docker]
```

| | default | |
| --- | --- | --- |
| `name` | required | the project's name (the type's title): lower-case letters, digits, `-` and `_` |
| `content` | required | the compose file, as text |
| `env` | `{}` | variables for the compose file. They are written to `.env` next to it, readable by root only, and never shown in a plan or a report. Empty leaves `.env` alone |
| `dir` | `<docker_compose_dir>/<name>` | the project's directory. Relative paths in the compose file start here |
| `ensure` | `present` | `absent` stops the project and removes its containers, networks and files |

What it does, at every run:

- **It writes `compose.yaml`** (and `.env`). Docker Compose reads the new
  file before it replaces the old one; a mistake in it fails the run with
  Compose's own message, and the running project is left alone.
- **It keeps the project as the file says.** Per service: a container
  exists, it was made from the service as the file now describes it, and
  it is running. A service that was added is started, one that changed
  is recreated, one that left the file is removed, a container that
  stopped is started again - and services that did not change are not
  touched. A plan lists these per service.
- A service that ended by itself with success, as a job does, counts as
  right and is not run again. One that ended with an error is started
  again at every run until it succeeds.
- A change of a value in `env` recreates the services that use it.

Things to know about projects:

- **Volumes are never removed**, not by a change and not by
  `ensure: absent`. Remove them yourself (`docker volume rm`) when the
  data may go.
- Images are pulled when a container is created. A newer image under the
  same tag is not noticed: name the version in the tag, and change the
  tag to upgrade.
- Bringing a project up may take five minutes at most, pulling included.
  If large images take longer, the run fails there and the next run
  carries on where the pull got to.
- A secret in `env` belongs in your data encrypted or from Vault, as any
  secret; here it ends in a file only root can read. It is visible to
  whoever may inspect the container - in other words, to `docker_users`.
- A compose file with `{{ ... }}` in it (a healthcheck format, say) meets
  fleetreeve's own templates first. Write `{{ "{{" }}` for a literal `{{`.
- **Use `ensure: absent` to remove a project.** Merely taking it out of
  `docker_compose` removes its `compose.yaml` and `.env`, which fleetreeve
  made, but leaves the containers running: fleetreeve does not undo what
  a script type did when it leaves the manifest.

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
settings, a refused setting, and both ways of handling a restart; and for
Compose projects, bringing one up, changes to the file and to `.env`, a
stopped container, a removed service, a refused file, and removal. The
other distributions named above use the same two code paths but were not
run. Not tried on a host that also has podman.
