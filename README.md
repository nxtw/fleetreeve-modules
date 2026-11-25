# fleetreeve modules

Modules for [fleetreeve](https://github.com/nxtw/fleetreeve), maintained
alongside it. A module bundles roles and resource types around one
subject, so that a project can manage it without writing the manifests
itself.

| Module | What it manages | Roles | Types |
| --- | --- | --- | --- |
| [`fleetreeve.nginx`](fleetreeve.nginx) | nginx, and virtual hosts as resources of their own | `main` | `fleetreeve.nginx.vhost` |
| [`fleetreeve.firewalld`](fleetreeve.firewalld) | firewalld, and open ports as resources of their own | `main` | `fleetreeve.firewalld.port` |
| [`fleetreeve.gitlab_runner`](fleetreeve.gitlab_runner) | GitLab Runner from GitLab's own repository, with its runners configured from data (Red Hat family) | `main` | `fleetreeve.gitlab_runner.runner` |

Each module's own README says what its roles do, which variables they
read and which parameters its types take.

## Using a module

In your project directory (the one with your `site.yaml`), add the module
you want, at a released version:

```sh
fleetreeve module add https://github.com/nxtw/fleetreeve-modules.git -path fleetreeve.nginx -version v0.2.0
```

`-path` names the module inside this repository; `-version` is one of its
[tags](https://github.com/nxtw/fleetreeve-modules/tags). The module is
copied into `modules/` in your project, and its source, version, exact
commit and a checksum are recorded in `modules.yaml` and `modules.lock`.
Commit all of that with your project.

Then use it:

```yaml
# site.yaml
include:
  - module: fleetreeve.nginx

resources:
  - fleetreeve.nginx.vhost: www
    server_name: www.example.com
    root: /usr/share/nginx/html/www
```

```sh
fleetreeve module list                    # what is installed, with its roles and types
fleetreeve types fleetreeve.nginx.vhost   # one type and its parameters
fleetreeve plan site.yaml                 # what it would change
```

A module's roles and scripts run as root on your hosts. Read what you add,
as you would any code.

## Updating

Run `fleetreeve module add` again with the new version. It replaces the
module and its lock entry, and `git diff` in your project then shows
exactly what changed. [CHANGELOG.md](CHANGELOG.md) says what each version
changed and whether you have to change anything.

## Versions

The repository is tagged as a whole: `v0.2.0` is one state of all modules.
Each module also carries its own `version:` in `module.yaml`, which only
goes up when that module changes. Versions follow semantic versioning: a
new major version when a project has to change something to keep working,
a minor one for additions, a patch for fixes.

The modules need fleetreeve 0.1.0 or later.

## Checking the modules

```sh
tests/run.sh
```

With `fleetreeve` on your `PATH` (or `FLEETREEVE=/path/to/fleetreeve`),
this loads every module, compiles [a manifest](tests/site.yaml) that uses
every role and type against the facts of a CentOS Stream 9 host, and
installs each module into an empty project the way a user would. CI runs
the same script with the latest fleetreeve release on every push and pull
request.

It checks that modules are well-formed, not what they do on a host: test a
change on a throwaway machine as well.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Writing modules is covered in
fleetreeve's
[Developing modules](https://github.com/nxtw/fleetreeve/blob/main/docs/module-development.md)
guide. Modules under another namespace than `fleetreeve.` are best kept in
a repository of your own: `fleetreeve module add` takes any git URL.

Security problems are reported privately; see [SECURITY.md](SECURITY.md).

## Licence

[Apache-2.0](LICENSE).
