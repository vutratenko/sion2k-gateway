# Telemt (MTProto) на общем shturval-gateway

Проверенная схема для зонтичного DNS на **`192.168.88.9`**: обычные сайты и **telemt** на одном VIP, маршрутизация по **SNI**.

Деплой приложения: [telemt-k8s](https://github.com/vutratenko/telemt-k8s). Маршрут и listener: этот репозиторий (`generate_manifests.py` → `dist/`).

## Не путать с HTTP

| | Сайты | Telemt |
|---|--------|--------|
| Протокол на краю | HTTPS Terminate | **TLS Passthrough** |
| Gateway API | HTTPRoute | **TLSRoute** |
| Сертификат на Gateway | да (Secret в `gateway-system`) | **нет** (Fake TLS в pod) |
| Backend | Service :80/:443 HTTP | Service `telemt:8443` |

HTTPRoute для `cheeseburger.sion2k.ru` **ломает** MTProxy.

## Объекты в кластере

```
Client :443 (SNI cheeseburger.sion2k.ru)
  → LoadBalancer shturval-gateway (192.168.88.9)
  → Envoy filter chain: tls-passthrough (не terminate)
  → TLSRoute/telemt (namespace telemt)
  → Service/telemt:8443 → Pod Fake TLS
```

Манифесты:

- `dist/03-listenerset-sion2k.yaml` — listener `tls-cheeseburger-sion2k-ru-passthrough` (`protocol: TLS`, `tls.mode: Passthrough`).
- `dist/httproutes/telemt-tlsroute.yaml` — `parentRef` → `ListenerSet/sion2k-app-listeners`, `sectionName` = имя listener.
- `dist/02-reference-grants-tlsroute.yaml` — разрешение TLSRoute из namespace `telemt`.

## Проверка после apply / Argo sync

```bash
kubectl get listenerset -n gateway-system sion2k-app-listeners -o jsonpath=\
'{.status.listeners[?(@.name=="tls-cheeseburger-sion2k-ru-passthrough")].attachedRoutes}{"\n"}'
# 1

kubectl get tlsroute -n telemt telemt -o jsonpath=\
'{range .status.parents[0].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
# Accepted=True ResolvedRefs=True
```

Рабочий критерий — **клиент Telegram** с `ee…` ссылкой (`server=cheeseburger.sion2k.ru`, `port=443`). Обычный `curl/openssl` часто не завершает handshake: это Fake TLS, не веб-сайт.

## Типичные ошибки

1. **Отдельный Gateway на другом VIP (.114)** при зонтике на `.9` — клиенты не попадают на passthrough. По умолчанию генератор вешает telemt на **тот же** `shturval-gateway` (см. ниже).
2. **HTTPS listener + cert** для `cheeseburger` в ListenerSet — терминация на краю, MTProto не работает.
3. **Ingress nginx ssl-passthrough** параллельно с Gateway на том же IP — внешний трафик идёт только на Cilium LB; ingress в кластере для telemt не нужен (см. telemt-k8s).
4. **Путать с HTTPRoute** — только TLSRoute.

## Генератор

По умолчанию (`SION2K_TELEMT_DEDICATED_GATEWAY` не задан или `0`):

- passthrough listener в `sion2k-app-listeners`;
- TLSRoute на ListenerSet.

Опционально отдельный Gateway (свой A-record на cheeseburger):

```bash
export SION2K_TELEMT_DEDICATED_GATEWAY=1
export SION2K_TELEMT_GATEWAY_VIP=192.168.88.114   # пример
python3 generate_manifests.py
```

## История

- Раньше: nginx Ingress `ssl-passthrough` на `.9`.
- Промежуточно: ошибочная попытка HTTPRoute / отдельный Gateway `.114` без DNS под него.
- Текущая: **TLSRoute + ListenerSet** на `shturval-gateway`, зонтик DNS на `.9`.
