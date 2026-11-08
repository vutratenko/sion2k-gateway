# Kubeflow: SSC `kubeflow-step-2` → Gateway `shturval-gateway` (без nginx Ingress)

Публикация UI Kubeflow на `kubeflow.sion2k-cluster.sion2k.ru` через платформенный Cilium Gateway **`shturval-gateway`** (`gateway-system`) + ListenerSet `sion2k-app-listeners` и HTTPRoute из этого репозитория (`dist/httproutes/kubeflow-cluster.yaml`). Istio внутри кластера не меняем; с nginx Ingress на `.9` только снимаем дубль.

## Предусловия

1. Argo/`sion2k-gateway` применён: listener + HTTPRoute `istio-system/kubeflow-cluster` → `istio-ingressgateway:80`, `ResolvedRefs=True`.
2. TLS secret `kubeflow-cluster-tls` (или alias из `dist/TLS_AND_PORTS.md`) есть в `gateway-system`.
3. DNS/NAT на VIP Gateway **`192.168.88.9`**.

## Фрагмент `customvalues` (вкладка «Манифест» SSC или merge)

```yaml
platform-agnostic-mutli-user:
  exposure: gateway
  gateway:
    create: false
    name: shturval-gateway
    namespace: gateway-system
  ingress:
    enabled: false
```

Остальные ключи в `spec.customvalues` (`centraldashboard`, `kserve`, `mlPipeline`, …) **не трогать**.

## Применение из CLI (merge, без затирания остальных customvalues)

```bash
# из корня репозитория sion2k-gateway
./scripts/patch-kubeflow-step-2-ssc.sh
```

Скрипт читает текущий `ShturvalServiceConfig/kubeflow-step-2`, выставляет блок выше в `platform-agnostic-mutli-user`, делает `kubectl apply`.

## Проверка

```bash
# SSC применил значения (не только spec)
kubectl get shturvalserviceconfig kubeflow-step-2 -o jsonpath='{.status.appliedCustomValues.platform-agnostic-mutli-user.ingress.enabled}{"\n"}'
# ожидается: false

kubectl get ingress -n istio-system
# не должно быть kubeflow-step-2-platform-agnostic-mutli-user

VIP=192.168.88.9
curl -sk -o /dev/null -w "%{http_code}\n" \
  --resolve "kubeflow.sion2k-cluster.sion2k.ru:443:${VIP}" \
  "https://kubeflow.sion2k-cluster.sion2k.ru/"
```

Если `status.conditions` SSC: `GitOpsEngineNotReady` / `ErrorServiceNotHealthy` — дождаться Healthy в **Установленные сервисы** или починить зависимости; пока `appliedCustomValues` отстаёт, Helm может снова создать Ingress.

## Откат (nginx на .9)

В SSC вернуть:

```yaml
platform-agnostic-mutli-user:
  ingress:
    enabled: true
    ingressClassName: nginx
    # rules/tls как были (host kubeflow.sion2k-cluster.sion2k.ru → istio-ingressgateway:8080)
```

И при необходимости убрать HTTPRoute с `shturval-gateway` из GitOps (не рекомендуется при живом DNS на `.9`).
