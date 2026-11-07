# sion2k-gateway

GitOps для **общего** Cilium Gateway `public` в `gateway-system` и HTTPRoute для неплатформенных сервисов кластера sion2k. Платформенные Ingress (shturval-*, postgres-operator-ui, shturval-dashboards) **не** меняются здесь.

## Зависимости

- GatewayClass `cilium` и контроллер Gateway API в Cilium (включается в рамках платформы).
- `CiliumLoadBalancerIPPool` с адресом для VIP Gateway (пример ниже).
- TLS: в `spec.listeners[].tls.certificateRefs` Gateway ссылается на Secret в **gateway-system**. Если сертификаты раньше жили только в неймспейсе приложения, скопируйте Secret в `gateway-system` **или** выпустите отдельный `Certificate` cert-manager в `gateway-system` с тем же `dnsNames`. Для хоста с несколькими Ingress и разными `secretName` (Challenger API) на практике нужен **один** Secret на hostname на стороне Gateway.

## Генерация манифестов

```bash
cd "$(dirname "$0")"
set -a && source generate.env && set +a
python3 generate_manifests.py
```

Создаёт каталог `dist/`:

- `00-namespace.yaml` — по желанию только если gateway-system создаёте сами (иначе уберите из kustomization).
- `01-cilium-pool.yaml` — **задайте** блок в `CiliumLoadBalancerIPPool` (CIDR или IP).
- `02-reference-grants.yaml` — ReferenceGrant: сервисы в других неймспейсах разрешают Gateway `public` ссылаться на секреты (TLS) и HTTPRoute прикрепляться.
- `03-gateway-public.yaml` — Gateway + слушатели HTTPS (и HTTP redirect, если поддерживается вашей версией Cilium).
- `httproutes-*.yaml` — маршруты по приложениям.

Проверка до переключения DNS (как в плане):

```bash
GATEWAY_VIP=<ip из kubectl get gateway public -n gateway-system>
curl -k --resolve meet.sion2k.ru:443:$GATEWAY_VIP https://meet.sion2k.ru/
```

## Argo CD

```bash
kubectl apply -f argocd/application.yaml
```

Приложение синхронизирует `dist/` после локального запуска `generate_manifests.py` и коммита. При желании добавьте CI job, который коммитит `dist/` при изменении `generate_manifests.py`.

## Inventory (живой кластер)

С машины с доступом к API:

```bash
./scripts/cluster-inventory.sh
```

При последнем запуске агента `kubectl` к API вернул `no route to host` — инвентаризацию выполните с рабочей сети и поправьте `scripts/cluster-inventory.sh` при необходимости.

## Связка с приложениями

- **advance-report**, **teammapper**: после появления Gateway `public` Ingress должен указывать на Service `cilium-gateway-public` вместо старых `cilium-gateway-advance-report` / `cilium-gateway-teammapper`; локальный per-app Gateway удаляется. См. изменения в `advance-report/deploy/` и `teammapper-helm/`.
- **Challenger**: в `values`/`argocd-application` выставить `ingress.enabled: false` после переноса TLS и проверки HTTPRoute (секреты в Data содержат чувствительные поля — при правке `argocd-application.yaml` не копируйте секреты в новые коммиты).
- **Kubeflow**: перевод чарта на `exposure: gateway` с `gateway.create: false` и общим `public` описан в комментариях внутри `generate_manifests.py` (HTTPRoute в `istio-system`). Пока в tree только ingress-values; полный values patch делается в репозитории, из которого ставится Kubeflow.

## Telemt (TLS passthrough)

Для `cheeseburger.sion2k.ru` (telemt): Gateway listener **TLS Passthrough** + `TLSRoute` на Service `telemt:8443` (см. `dist/httproutes/telemt-tlsroute.yaml`). Не терминируйте TLS на Gateway для этого хоста.

## Остальные приложения (не в этом PR)

HTTPRoute для cal-com, mlflow, familygram и т.д. лежат в `dist/httproutes/`. Чтобы убрать дублирующий Ingress после проверки, выключите ingress в соответствующих Helm values / сырых манифестах (как сделано для Challenger).

## Kubeflow

HTTPRoute в `dist/httproutes/kubeflow-*.yaml` → `istio-ingressgateway`. Публикация через SSC (не сырой Helm):

- [docs/kubeflow-ssc-public-gateway.md](docs/kubeflow-ssc-public-gateway.md)
- `./scripts/patch-kubeflow-step-2-ssc.sh` — merge в `ShturvalServiceConfig/kubeflow-step-2`: `ingress.enabled: false`, `exposure: gateway`, `gateway.create: false`, `name: public`, `namespace: gateway-system`.
