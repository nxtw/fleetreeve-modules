# fleetreeve.firewalld

Installs and runs firewalld, and adds a resource type for open ports.

```yaml
include:
  - module: fleetreeve.firewalld          # firewalld itself, plus every port in `open_ports`

resources:
  - fleetreeve.firewalld.port: 8443/tcp   # or declare ports where they belong
    require: service[firewalld]
```

| | |
| --- | --- |
| role `main` | package and service; opens each port in the variable `open_ports` (a list of numbers, TCP) |
| type `fleetreeve.firewalld.port` | one port, titled `<port>/<protocol>`; parameters `ensure` (`open`, `closed`) and `zone` |

The type is a shell script (`types/port.sh`) that asks `firewall-cmd` for
the port's state, permanent and running, and changes both - so a newly
declared port works at once and survives a reload, and no reload handler
is needed.
