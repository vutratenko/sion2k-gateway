# sion2k-gateway

GitOps для неплатформенных сервисов на **Cilium Gateway API**: платформенный `shturval-gateway` (VIP `192.168.88.9`) + `ListenerSet/sion2k-app-listeners` в `gateway-system` и HTTPRoute/TLSRoute по приложениям. Платформенные маршруты (shturval-*, postgres-operator-ui, shturval-dashboards) **не** меняются здесь.

## Зависимости

- GatewayClass `cilium` и `Gateway/shturval-gateway` (управляется cluster-manager — **не** патчить `spec.listeners` у Gateway).
- Прикладной HTTPS: listeners в `ListenerSet/sion2k-app-listeners`, `parentRef` → `shturval-gateway`.
- TLS: terminate-секреты в **gateway-system** (`certificateRefs` в ListenerSet). Скопируйте Secret из неймспейса приложения или выпустите `Certificate` в `gateway-system`. Для Challenger API — один Secret на hostname.
- Cross-namespace: `ReferenceGrant` в `gateway-system` на `ListenerSet/sion2k-app-listeners`.

## Генерация манифестов

```bash
cd "$(dirname "$0")"
set -a && source generate.env 2>/dev/null; set +a
python3 generate_manifests.py
```

Создаёт каталог `dist/`:

- `03-listenerset-sion2k.yaml` — HTTPS listeners + TLS passthrough (telemt).
- `04-sion2k-http-redirect*.yaml` — HTTP→HTTPS для прикладных hostnames (listener `http` на `shturval-gateway`).
- `02-reference-grants*.yaml` — HTTPRoute/TLSRoute из других namespace.
- `httproutes/*.yaml` — маршруты по приложениям.

Проверка до/после DNS:

```bash
VIP=192.168.88.9
curl -sk --resolve meet.sion2k.ru:443:$VIP -o /dev/null -w "%{http_code}\n" https://meet.sion2k.ru/
```

## Argo CD

```bash
kubectl apply -f argocd/application.yaml
```

Приложение синхронизирует `dist/` после коммита. При желании добавьте CI job, который регенерирует `dist/` при изменении `generate_manifests.py`.

## Inventory (живой кластер)

```bash
./scripts/cluster-inventory.sh   # GATEWAY_NAME по умолчанию: shturval-gateway
```

## Связка с приложениями

- **advance-report**, **teammapper**, **Challenger**, и др.: `ingress.enabled: false` в своих репозиториях после `HTTPRoute` `Accepted`.
- **Kubeflow**: HTTPRoute в `istio-system` → `istio-ingressgateway:80`. SSC — [docs/kubeflow-ssc-public-gateway.md](docs/kubeflow-ssc-public-gateway.md), `./scripts/patch-kubeflow-step-2-ssc.sh` (`gateway.name: shturval-gateway`).

## Telemt (TLS passthrough)

Хост `cheeseburger.sion2k.ru` — **только** TLS Passthrough, без HTTPS Terminate на Gateway.

- Listener: `tls-cheeseburger-sion2k-ru-passthrough` в `03-listenerset-sion2k.yaml`.
- `TLSRoute/telemt` в namespace `telemt`: `parentRef` → **`ListenerSet/sion2k-app-listeners`** (фактическая схема Cilium/Shтурвал), `backendRefs` → `telemt:8443`.

Подробности деплоя telemt, генерация ссылок и проверки: [telemt-k8s README](https://github.com/vutratenko/telemt-k8s).

## Остальные приложения

HTTPRoute в `dist/httproutes/` — `parentRefs` на `ListenerSet/sion2k-app-listeners`, hostname совпадает с listener. После проверки отключите дублирующий Ingress в Helm/манифестах приложений.
