# fleetreeve.accounts

People's accounts from data: the user, the SSH keys that may log in as it,
its groups, and sudo. For any Linux fleetreeve manages.

```yaml
# site.yaml
include:
  - module: fleetreeve.accounts
```

```yaml
# data/common.yaml
accounts_groups: [admins]
accounts:
  - name: alice
    uid: 2001
    comment: Alice Example
    groups: [admins]
    keys:
      - ssh-ed25519 AAAAC3Nza… alice@laptop
    sudo: true
  - name: bob
    keys:
      - ssh-ed25519 AAAAC3Nza… bob@desk
  - name: carol
    ensure: absent                 # she left: remove the account everywhere
```

| | |
| --- | --- |
| role `main` | the groups in `accounts_groups`, then one account per entry in `accounts` |
| type `fleetreeve.accounts.user` | one account, titled by its login name. Can be used on its own in a manifest |
| type `fleetreeve.accounts.authorized_keys` | the keys of one account, titled by its login name; parameter `keys`. The `user` type declares it for you; use it on its own for an account that something else creates |

## Variables

| | default | |
| --- | --- | --- |
| `accounts` | `[]` | the accounts; fields below |
| `accounts_groups` | `[]` | groups to create before the accounts, by name |
| `accounts_shell` | `/bin/bash` | the shell of accounts that name none |
| `accounts_home` | `/home` | where home directories are made |

Each entry of `accounts`, and each parameter of the type:

| | default | |
| --- | --- | --- |
| `name` | required | the login name (the type's title) |
| `ensure` | `present` | `absent` removes the account and its sudo rights |
| `uid` | chosen by the system | give one when files are shared between hosts, so that a person has the same id everywhere |
| `comment` | | the person's full name |
| `shell` | `accounts_shell` | |
| `home` | `<accounts_home>/<name>` | |
| `groups` | `[]` | groups besides the account's own. They must exist: list them in `accounts_groups` |
| `keys` | `[]` | public keys that may log in, one per item |
| `sudo` | `false` | may run any command as root, without a password |

## What is managed, and what is not

- **`keys` is the whole list.** `~/.ssh/authorized_keys` is written from
  it, so a key someone added by hand is removed at the next run, and
  taking a key out of the data takes away that access. With no keys
  listed, the file is not managed at all.
- **The keys are written as the account, not as root.** A home directory
  belongs to its account, which can put a symbolic link anywhere in it. If
  root wrote there, a link from `.ssh` to `/root/.ssh` would turn "write
  alice's keys" into "let alice log in as root". So the part that touches
  the home directory runs as the account itself (`runuser`), where a link
  leads nowhere the account could not go anyway; a `.ssh` or
  `authorized_keys` that is a link is replaced by a real one. That process
  gets nothing of root's: an empty environment, and no terminal. This
  needs the home directory to exist, and `runuser` and `setsid`
  (util-linux, which every mainstream distribution has).
- **`groups` is the whole list** too: the account is taken out of groups
  that are not listed.
- **Passwords are not set.** An account made here has none and logs in
  with its keys only; that is why `sudo: true` asks for no password. Each
  account with sudo gets a file of its own in `/etc/sudoers.d`, checked
  with `visudo` before it lands. Setting `sudo: false` removes it.
- **`ensure: absent` leaves the home directory**, with whatever the person
  kept there. Remove it yourself when you are sure. Processes of the
  account that are still running are not ended.
- **Removing an entry from the data** removes the account if fleetreeve
  created it, and leaves it alone if it existed before; that is how
  fleetreeve treats everything it stops managing. Use `ensure: absent`
  when you want an account gone whoever made it.

## Things to know

- Do not list the account fleetreeve itself connects with (`fleetreeve`
  after `fleetreeve identity init`): its key and sudo rights are set up by
  `fleetreeve enroll`, and managing `keys` here would replace that key.
- With `fleetreeve.sshd` and `sshd_allow_groups`, an account can only log
  in when one of its `groups` is allowed there.
- Public keys are not secrets and can sit in your data as they are.
- With SELinux, the keys get the label sshd insists on (`ssh_home_t`),
  whether fleetreeve runs from a shell or as the pull service.
- Do the same in your own roles: do not use a `file` resource with an
  `owner` inside a directory that an unprivileged account owns.
- A login name with a dot (`first.last`) works; its sudoers file is named
  with an underscore instead, because sudo skips files with a dot in
  their name.
- Different people on different hosts: put `accounts` in the data of a
  group or a host. A list in a more specific data file replaces the one
  from `common.yaml`, unless your `site.yaml` merges it
  (`merge: {accounts: unique}`).
