# fleetreeve.gitlab_runner

Installs [GitLab Runner](https://docs.gitlab.com/runner/) from GitLab's
package repository, writes `/etc/gitlab-runner/config.toml` from your data,
and keeps the service running. For the Red Hat family (CentOS Stream, RHEL,
Rocky, Alma); on anything else it stops with a message rather than doing
half the job.

```yaml
# site.yaml
include:
  - manifest: roles/…
  - module: fleetreeve.gitlab_runner
    when: contains "ci" .host.groups
```

```yaml
# data/groups/ci.yaml
gitlab_runner_concurrent: 4
gitlab_runners:
  - name: "{{ .host.name }}-shell"
    url: https://gitlab.example.com
    token: glrt-…                       # the runner's authentication token
    executor: shell
  - name: "{{ .host.name }}-containers"
    url: https://gitlab.example.com
    token: glrt-…
    executor: docker
    docker:
      image: almalinux:9                # the default image for jobs that name none
      volumes: ["/cache"]
gitlab_runner_podman: true              # run those containers on podman
```

## Two ways to get runners onto a host

**Write them** (`gitlab_runners`, above): you create each runner in GitLab,
paste its `glrt-` token into the data, and fleetreeve writes `config.toml`.
Nothing on the host talks to GitLab until the runner starts. Every setting
is in your data and shows up in a plan.

**Register them** (`gitlab_runner_register`): the host runs
`gitlab-runner register` itself - and, given an access token, first creates
the runner in GitLab, so there is nothing to click or paste per host:

```yaml
# data/groups/ci.yaml
gitlab_runner_register:
  - name: "{{ .host.name }}"
    url: https://gitlab.example.com
    access_token: '{{ env "GITLAB_RUNNER_PAT" }}'   # scope: create_runner
    runner_type: group_type                          # or instance_type, project_type
    group_id: 42
    tags: [linux, "{{ .facts.os.name }}"]
    executor: docker
    docker_image: almalinux:9
```

- With `access_token`, the first run creates the runner in GitLab (with its
  type, tags, `run_untagged`, `locked`) and keeps the token GitLab returns
  in `/etc/gitlab-runner/fleetreeve/`, readable by root only. Later runs use
  that; the access token is needed once and can then be left out or expire.
- With `token: glrt-…` instead, an existing runner is registered.
- Changing a host-side setting (executor, limit, the docker settings,
  environment) registers the runner again with the same token; in GitLab it
  stays the same runner. Tags and the other GitLab-side settings are only
  set when the runner is created - change them in GitLab afterwards.
- `ensure: absent` unregisters the runner, and deletes it in GitLab if
  fleetreeve created it there. Removing the entry from the list does neither:
  set `ensure: absent` first, remove the entry later.
- A plan never contacts GitLab.

Use one way per host. With `gitlab_runner_register` set, fleetreeve manages only
`concurrent` and `check_interval` in `config.toml` and leaves the runners in
it to `gitlab-runner`. The entries take: `name`, `url`, `token` or
`access_token`, `runner_type`, `group_id`, `project_id`, `tags`,
`run_untagged`, `locked`, `executor`, `limit`, `environment`,
`docker_image`, `docker_privileged`, `docker_volumes`, `docker_pull_policy`,
`docker_host`, `tls_ca_file`, `register_args`, `ensure` - see
`fleetreeve types fleetreeve.gitlab_runner.runner`. The type can also be used on its
own in a manifest.

## Getting a token

Runners are created in GitLab, not on the host: *Settings → CI/CD → Runners →
New runner* (project, group or instance), where you also choose its tags and
whether it runs untagged jobs. GitLab then shows an authentication token
starting with `glrt-`. That token is all this module needs; there is no
`gitlab-runner register` step, and nothing to un-register when a host goes
away - delete the runner in GitLab.

## Variables

| | default | |
| --- | --- | --- |
| `gitlab_runners` | `[]` | the runners on this host, see below |
| `gitlab_runner_concurrent` | `1` | jobs the host runs at the same time, over all its runners |
| `gitlab_runner_check_interval` | `3` | seconds between asking GitLab for jobs |
| `gitlab_runner_version` | `""` | pin a package version such as `17.5.0-1`; empty installs the newest once and then leaves it |
| `gitlab_runner_podman` | `false` | install podman and point `docker` executors at it |

Each entry of `gitlab_runners`:

| | | |
| --- | --- | --- |
| `name` | required | as shown in the runner's logs |
| `url` | required | your GitLab, e.g. `https://gitlab.example.com` |
| `token` | required | the `glrt-…` token of the runner |
| `executor` | `shell` | `shell` or `docker` |
| `limit` | | jobs this one runner takes at a time |
| `environment` | | list of `NAME=value` given to every job |
| `builds_dir`, `cache_dir` | | where jobs are checked out, and their cache |
| `docker.image` | `almalinux:9` | image for jobs that name none |
| `docker.privileged` | `false` | needed for building images inside jobs; it gives jobs root on the host |
| `docker.volumes` | `["/cache"]` | |
| `docker.pull_policy` | | e.g. `if-not-present` |
| `docker.host` | | the engine's socket; set for you with `gitlab_runner_podman` |
| `extra` | | lines of TOML added to the runner as they are, for anything not listed |

## Things to know

- **The tokens are secrets and sit in your data in plain text.** fleetreeve keeps
  `config.toml` out of diffs and reports (`sensitive`), and the file is
  readable by root only, but the data file is as readable as your
  repository is. Keep the tokens out of it by passing them at run time
  (`token: '{{ env "CI_TOKEN" }}'`, read where fleetreeve compiles) if that
  matters to you.
- An `access_token` is a stronger secret than a runner token: it can create
  runners. It travels to the host inside the catalog. Prefer a group or
  project access token limited to the `create_runner` scope, pass it from
  the environment where fleetreeve compiles (`env`), and let it expire.
- GitLab Runner re-reads `config.toml` by itself within seconds, so a
  change does not restart the service and does not interrupt running jobs.
- A `shell` runner runs jobs as the `gitlab-runner` user, directly on the
  host. Whoever can push a pipeline can run commands there.
- Upgrades: with `gitlab_runner_version` empty, fleetreeve installs the package
  and then leaves the version to your normal patching (`dnf upgrade`).
