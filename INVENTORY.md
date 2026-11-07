# Cluster inventory (2026-11-07)

`kubectl` from the agent environment could not reach the API server (`dial tcp …:6443: no route to host`). No live object dump was collected.

Run on a host with cluster access:

```bash
./scripts/cluster-inventory.sh
```

Compare the output to `dist/TLS_AND_PORTS.md` and fix Secret names in `generate_manifests.py` if they differ.
