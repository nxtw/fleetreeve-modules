# fleetreeve.sshd

Keeps the OpenSSH server installed, running and hardened. Settings go into
a drop-in file that sshd checks before it goes live, so a mistake in your
data never reaches the running server. For systems whose `sshd_config`
includes `/etc/ssh/sshd_config.d` (RHEL/CentOS 9, Debian 12, Ubuntu 22.04
and later); on older ones the role stops and says so.

```yaml
# site.yaml
include:
  - module: fleetreeve.sshd
```

```yaml
# data/common.yaml
sshd_settings:
  PasswordAuthentication: "no"
  PermitRootLogin: "no"
sshd_allow_groups: [admins, fleetreeve]
```

| | |
| --- | --- |
| role `main` | the package, `/etc/ssh/sshd_config.d/00-fleetreeve.conf`, and the service; a change reloads sshd, which leaves open sessions alone |
| type `fleetreeve.sshd.config` | a further drop-in, titled by its file name without `.conf`; parameter `content` (required). For `Match` blocks and whatever else does not fit `sshd_settings` |

## Not locking yourself out

fleetreeve reaches your hosts over SSH, and so do you. Two settings can
shut both out, and sshd will accept them without complaint:

- **`sshd_allow_groups` and `sshd_allow_users`.** Once either is set,
  nobody else gets in. The list must include the account fleetreeve
  connects with (`user:` in the inventory; `fleetreeve` after
  `fleetreeve identity init`) or a group it is in, and your own.
- **`PermitRootLogin: "no"`** when fleetreeve, or you, log in as root.

The module checks that sshd can *parse* the configuration. It cannot know
who you meant to let in. Before applying such a change to every host, try
it on one with a session open: a reload does not end open sessions, so you
can still put it right.

The defaults are chosen so that including the module with no data locks
nobody out.

## Variables

| | default | |
| --- | --- | --- |
| `sshd_settings` | `{}` | your settings, as `sshd_config` spells them. Each one is added to the baseline or replaces its value |
| `sshd_baseline` | see below | what the module sets when you say nothing |
| `sshd_allow_groups` | `[]` | only members of these groups may log in; empty sets no limit |
| `sshd_allow_users` | `[]` | only these users may log in; empty sets no limit |
| `sshd_service` | `""` | the service's name; empty means `ssh` on Debian and Ubuntu and `sshd` elsewhere |
| `sshd_package` | `openssh-server` | |
| `sshd_dropin` | `00-fleetreeve` | the drop-in's file name, without `.conf` |

The baseline:

```yaml
sshd_baseline:
  PermitRootLogin: prohibit-password     # root may log in with a key, never with a password
  PermitEmptyPasswords: "no"
  X11Forwarding: "no"
  MaxAuthTries: 4
```

`sshd_settings` is laid over it setting by setting: the example at the top
gives a host five settings, not two. To drop a baseline setting rather
than change it, set `sshd_baseline` yourself.

Values are passed to sshd as you write them: `yes` and `no` work with or
without quotes.

## How it wins over the distribution's settings

sshd keeps the *first* value it reads for a setting, and current
distributions include `/etc/ssh/sshd_config.d/*.conf` at the top of
`sshd_config`. A file that sorts first therefore wins over the vendor's
drop-ins (on CentOS 9, `50-redhat.conf` switches X11 forwarding on) and
over the main file, which is never edited. That is why the drop-in is
called `00-fleetreeve`; if you rename it, keep it first.

`sshd -T` on a host prints the configuration sshd actually uses.

## More drop-ins

```yaml
resources:
  - fleetreeve.sshd.config: 50-sftp-only
    content: |
      Match Group sftp
          ChrootDirectory /srv/sftp/%u
          ForceCommand internal-sftp
```

A `Match` block ends at the end of its file, so it does not affect the
drop-ins that follow. The file is checked like the main one, and put back
as it was if sshd refuses it.

## Things to know

- The check (`sshd -t`) runs on the new content before it replaces the
  file. If it fails, nothing changes, sshd is not reloaded, and the run
  reports the line sshd objects to.
- On a system where sshd was never started, the role makes the host keys
  first (`ssh-keygen -A`), and on Debian and Ubuntu the directory
  `/run/sshd`: without them sshd refuses to check anything.
- Changing `Port` needs more than this module: the firewall has to open
  the new port and, with SELinux, the port needs the type `ssh_port_t`
  (`fleetreeve.selinux.port`) before sshd is reloaded. Add the new port
  first, and take the old one away in a later change.
- Files in `sshd_config.d` that this module does not manage are left
  alone.
