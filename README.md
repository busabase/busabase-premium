# Busabase Premium — deployment

Deployment configuration for running [Busabase](https://busabase.com) Premium on your own
infrastructure. Two shapes, both maintained here:

| Directory | What it is | Use it when |
| --- | --- | --- |
| [`compose/`](./compose) | Docker Compose: app, Postgres, object storage and a one-shot migration job as separate services | Production on a single host — you can back up, tune and restart each piece independently |
| [`helm/`](./helm) | A Helm chart, same architecture expressed as Kubernetes objects | You already run Kubernetes |

Just evaluating? Neither of these is the fastest path. The all-in-one image bundles
Postgres and object storage into one container and needs no orchestration at all:

```bash
docker run -d --name busabase \
  -p 3000:3000 \
  -p 8333:8333 \
  -v busabase-data:/data \
  --restart unless-stopped \
  busabase/busabase-premium-allinone:trial
```

## Quick start

### Compose

```bash
cd compose
./init.sh                    # generates .env and seaweed-s3.json with matching credentials
docker compose up -d
```

Run `init.sh` rather than filling in `.env` by hand. The object-storage credentials appear
in two files that must agree, and getting them out of sync is the most common self-inflicted
failure here — the symptom is misleading, because the app starts and signs you in perfectly
and then every attachment upload fails.

### Helm

```bash
helm install busabase ./helm \
  --namespace busabase --create-namespace \
  --set image.tag=<version> \
  --set appUrl=https://busabase.company.internal
```

Both values are required; the chart refuses to render without them rather than installing
something that half-works. See [`helm/values.yaml`](./helm/values.yaml) for the rest,
including how to point at a Postgres and an S3 you already operate.

## Images

| Image | Contents |
| --- | --- |
| [`busabase/busabase-premium`](https://hub.docker.com/r/busabase/busabase-premium) | The application alone. What `compose/` and `helm/` both run, alongside their own Postgres and object storage. |
| [`busabase/busabase-premium-allinone`](https://hub.docker.com/r/busabase/busabase-premium-allinone) | Application + Postgres + object storage in one container, one `/data` volume. |

The two are not interchangeable: the all-in-one image generates its own credentials on first
boot and ignores `PG_DATABASE_URL`/`STORAGE_URL`, and the plain image has no embedded
database to fall back on.

## Licence

The images are commercial software and require a licence key. Everything **in this
repository** — the chart, the Compose file, the scripts — is MIT licensed, so you can fork
and adapt it to your own infrastructure freely.

An unlicensed instance starts, and stays read-only until a key is activated. Paste the key
under **System Admin → Licence**; it is verified locally against a public key compiled into
the build, so an instance that has never touched the internet activates exactly like one
that has.

## Documentation

- [Self-hosting overview](https://busabase.com/docs/self-hosted/overview) — which shape to pick, measured hardware requirements
- [Production with Compose](https://busabase.com/docs/self-hosted/production-compose)
- [Kubernetes (Helm)](https://busabase.com/docs/self-hosted/kubernetes-helm)
- [Configuration reference](https://busabase.com/docs/self-hosted/configuration) — every environment variable, its default, and whether changing it needs a restart
- [Backup and restore](https://busabase.com/docs/self-hosted/backup-restore)
- [Upgrading](https://busabase.com/docs/self-hosted/upgrade)
- [Installing without internet access](https://busabase.com/docs/self-hosted/offline-install)
- [Troubleshooting](https://busabase.com/docs/self-hosted/troubleshooting)

## Support

Issues with the deployment configuration itself — the chart, the Compose file, the scripts —
belong in this repository's issue tracker.

For anything touching your licence, your data, or the product itself, email
[support@busabase.com](mailto:support@busabase.com). `compose/support-bundle.sh` collects
logs, service status and a health check into one archive to attach; it redacts every value
in `.env` and keeps only the variable names.
