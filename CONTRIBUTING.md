# Contributing

Fixes and improvements to the modules here are welcome, and so are new
modules for subjects that many fleets share.

## Changing a module

1. Make the change in the module's directory.
2. Raise `version:` in its `module.yaml`: a patch for a fix, a minor
   version for an addition, a major one when a project using the module
   has to change something to keep working (a parameter or variable
   renamed or removed, a default that changes what hosts end up with).
3. Describe the change under "Unreleased" in [CHANGELOG.md](CHANGELOG.md),
   and say what users have to do, if anything.
4. Update the module's README when roles, variables or parameters change.
5. Run `tests/run.sh`, and try the change on a real host: the script
   checks that the module is well-formed, not what it does.

## Adding a module

A module here is named `fleetreeve.<subject>`, lives in a directory of
that name at the top of the repository, and has:

- `module.yaml` with `name`, `version` and a one-line `description`;
- a `README.md` that says what the roles do, which variables they read and
  which parameters the types take, with an example;
- an entry in the table in the top-level [README.md](README.md);
- its roles and types used in [tests/site.yaml](tests/site.yaml), so that
  they are compiled by the checks.

`tests/run.sh` fails when one of these is missing.

Keep a module to one subject, give every variable a default, and make
script types safe to run twice. fleetreeve's
[Developing modules](https://github.com/nxtw/fleetreeve/blob/main/docs/module-development.md)
guide has the details, and a checklist to go through before publishing.

## Pull requests

One subject per pull request. CI must pass. By contributing you agree that
your contribution is licensed under the [Apache License 2.0](LICENSE).
