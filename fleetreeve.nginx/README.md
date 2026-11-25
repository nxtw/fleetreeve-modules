# fleetreeve.nginx

Installs and runs nginx, and adds a resource type for virtual hosts.

```yaml
include:
  - module: fleetreeve.nginx              # nginx itself: package, nginx.conf, service

resources:
  - fleetreeve.nginx.vhost: www           # a site: web root, start page, server block
    server_name: www.example.com
    port: 8080
    root: /usr/share/nginx/html/www
```

| | |
| --- | --- |
| role `main` | package, `/etc/nginx/nginx.conf`, the service, and a check of the whole configuration before every reload. Reads `nginx_user`. |
| type `fleetreeve.nginx.vhost` | one site, titled by its short name. Parameters: `server_name` (required), `root` (required), `port` (default 80). |

A virtual host is written, then nginx checks the whole configuration, and
only then reloads. If the check fails the file is put back (or, if new,
removed) and nginx is not reloaded: one bad site never takes the others
down.

The type is composite: `types/vhost.yaml` is nothing but three `file`
resources with parameters, so `fleetreeve plan` shows exactly what a site
consists of.
