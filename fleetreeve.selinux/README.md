# fleetreeve.selinux

SELinux booleans, port labels and file contexts as resources, so that a
confined service is allowed exactly what your configuration gives it. For
hosts where SELinux is on: the Red Hat family by default (CentOS Stream,
RHEL, Rocky, Alma, Fedora).

```yaml
# site.yaml
include:
  - module: fleetreeve.selinux
```

```yaml
# data/groups/web.yaml
selinux_booleans: [httpd_can_network_connect]
selinux_ports:
  - {port: 8080/tcp, type: http_port_t}
selinux_fcontexts:
  - {path: "/srv/www(/.*)?", type: httpd_sys_content_t}
```

Or declare them where they belong, next to the service that needs them:

```yaml
resources:
  - fleetreeve.selinux.port: 8080/tcp
    type: http_port_t
    before: service[nginx]

  - fleetreeve.selinux.boolean: httpd_can_network_connect

  - fleetreeve.selinux.fcontext: "/srv/www(/.*)?"
    type: httpd_sys_content_t
```

| | |
| --- | --- |
| role `main` | installs `semanage`, sets the mode if you ask for one, and declares what the variables below list |
| type `fleetreeve.selinux.boolean` | a boolean, titled by its name; parameter `value` (`on`, `off`) |
| type `fleetreeve.selinux.port` | a port's type, titled `<port>/<protocol>` or `<from>-<to>/<protocol>`; parameters `type` (required), `ensure` |
| type `fleetreeve.selinux.fcontext` | the type of the files at a path, titled by the path pattern; parameters `type` (required), `ensure`, `relabel` |

On a host where SELinux is disabled or absent the role declares nothing,
so it can be included for every host. The types are different: used on
their own on such a host they fail and say so. Give them
`when: ne .facts.selinux "disabled"` in a manifest that also covers hosts
without SELinux.

## Variables

| | default | |
| --- | --- | --- |
| `selinux_mode` | `""` | `enforcing` or `permissive`: set now and for the next boot. Empty leaves the mode alone |
| `selinux_booleans` | `[]` | booleans to switch on, by name |
| `selinux_booleans_off` | `[]` | booleans to switch off |
| `selinux_ports` | `[]` | entries of `port` and `type`, optionally `ensure` |
| `selinux_fcontexts` | `[]` | entries of `path` and `type`, optionally `ensure` and `relabel` |
| `selinux_tools_package` | `policycoreutils-python-utils` | the package that provides `semanage` |

Lists in data replace each other: a host in two groups gets the list of
the more specific file. To have them add up, say so in your `site.yaml`:

```yaml
data:
  dir: data
  merge:
    selinux_booleans: unique
    selinux_ports: unique
    selinux_fcontexts: unique
```

## What the types do

**Booleans** are set for the running system and in the policy store, so
they hold after a reboot. A boolean that someone switched for the running
system only (`setsebool` without `-P`) is noticed and put back.

**Ports.** A port that has no label gets one; a port that already has a
label from the policy (9090 is `websm_port_t`, for instance) is changed
for this host. `ensure: absent` removes what was added or changed on the
host, after which the policy's own label applies again. Labels that come
with the policy cannot be removed, and `absent` leaves them alone.

**File contexts** record a rule in the policy and then give the files that
exist the labels the policy has for them (`restorecon`). Later runs check
both: the rule, and whether files under the path carry another label than
they should, which happens when files are moved in from elsewhere. The
check walks the tree on every run; for a very large one set
`relabel: false` and relabel by hand when needed. The path the labels are
checked from is the pattern up to its first special character:
`/srv/www(/.*)?` is checked from `/srv/www` down.

## Things to know

- fleetreeve writes files through a temporary file in the target
  directory, so new files get that directory's type. Files managed by
  fleetreeve below a path with the right context need nothing more.
- Order matters when a service starts: a port label has to be there
  before the service binds the port. Declare the label with
  `before: service[…]`, or include this module before the service's role;
  where nothing else decides, fleetreeve keeps the written order.
- Each boolean, port and context costs a call to `semanage` on every run,
  roughly half a second each on a small machine. A few dozen are fine;
  hundreds are not what this module is for.
- `selinux_mode` switches between enforcing and permissive only. Turning
  SELinux off or on changes the kernel's boot parameters and relabels the
  file system: do that deliberately, not from a role.
- Removing an entry from the data does not undo it on the hosts: fleetreeve
  cannot undo what a script type did. Set `ensure: absent` (or move a
  boolean to `selinux_booleans_off`) first, and remove the entry later.
