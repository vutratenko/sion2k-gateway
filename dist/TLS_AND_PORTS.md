# TLS secret names (must exist in gateway-system) and notes

## HTTPS terminate (ListenerSet listeners)

- `ao1.l4.sion2k.ru` → Secret `advance-report-tls`
- `teammapper.sion2k.ru` → Secret `teammapper-tls`
- `meet.sion2k.ru` → Secret `meet-sion2k-ru-tls`
- `auth.sion2k.ru` → Secret `authentik-tls` — copy from authentik ns
- `kubeflow.sion2k-cluster.sion2k.ru` → Secret `kubeflow-cluster-tls` — issue Certificate or copy; host must match live DNS
- `flow.ip-10-31-145-173.shturval.link` → Secret `kubeflow-ingress-tls`
- `mlflow.sion2k.ru` → Secret `mlflow-sion2k-ru-tls`
- `s3.sion2k.ru` → Secret `s3-sion2k-ru-tls` — Certificate in gateway-system; DNS A → gateway LB
- `jaws.sion2k.ru` → Secret `jaws-sion2k-ru-tls`
- `hass.sion2k.ru` → Secret `homeassistant-tls`
- `torrent.sion2k.ru` → Secret `torrent-sion2k-ru-tls` — add TLS Certificate; Ingress had force-ssl only
- `sion2k.ru` → Secret `sion2k-site-tls`
- `www.sion2k.ru` → Secret `sion2k-site-tls` — same cert as apex; separate listener for SNI www
- `ctf.sion2k.ru` → Secret `ctf-sion2k-ru-tls`
- `raffle.sion2k.ru` → Secret `raffle-sion2k-ru-tls`
- `registry.sion2k.ru` → Secret `harbor-ingress`
- `cloud.sion2k.ru` → Secret `nextcloud-tls`
- `familygram.sion2k.ru` → Secret `familygram-tls`
- `beauty.sion2k.ru` → Secret `beauty-sion2k-ru-tls`
- `sklad.sion2k.ru` → Secret `sklad-tls`
- `challenger.api.sion2k.ru` → Secret `challenger-api-sion2k-ru-tls` — consolidate per-Ingress secrets into one
- `challenger.sion2k.ru` → Secret `challenger-landing-prod-secret-ingress`
- `athlete.challenger.sion2k.ru` → Secret `challenger-athlete-prod-secret-ingress`
- `challenger-admin.sion2k.ru` → Secret `challenger-prod-secret-ingress`
- `challenger-crm.sion2k.ru` → Secret `challenger-espocrm-ingress-tls`
- `challenger-stage.api.sion2k.ru` → Secret `challenger-stage-api-tls` — consolidate stage API TLS secrets
- `athlete.challenger-stage.sion2k.ru` → Secret `challenger-athlete-stage-secret-ingress`
- `challenger-stage.sion2k.ru` → Secret `challenger-stage-secret-ingress`
- `challenger-landing-stage.sion2k.ru` → Secret `challenger-landing-stage-secret-ingress`
- `alerts.sion2k-cluster.sion2k.ru` → Secret `alerts-cluster-tls` — Certificate in gateway-system
- `budget.sion2k-cluster.sion2k.ru` → Secret `budget-inbox-tls` — Certificate in gateway-system

## TLS passthrough (no Secret on Gateway)

- `cheeseburger.sion2k.ru` → listener `tls-cheeseburger-sion2k-ru-passthrough`, TLSRoute `telemt/telemt` → Service `telemt:8443` (MTProto; not HTTPRoute). See docs/telemt-shared-gateway.md.
