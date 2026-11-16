# If Helm leaves `RemovePodsHavingTooManyRestarts` in `plugins.deschedule.enabled`, re-apply:

```bash
kubectl get configmap shturval-descheduler -n kube-system -o jsonpath='{.data.policy\.yaml}' | \
  python3 -c "
import sys, yaml, json
doc = yaml.safe_load(sys.stdin)
prof = doc['profiles'][0]
desc = prof['plugins']['deschedule']['enabled']
if 'RemovePodsHavingTooManyRestarts' in desc:
    desc.remove('RemovePodsHavingTooManyRestarts')
prof['pluginConfig'] = [p for p in prof['pluginConfig'] if p.get('name') != 'RemovePodsHavingTooManyRestarts']
doc.pop('strategies', None)
patch = json.dumps({'data': {'policy.yaml': yaml.dump(doc, default_flow_style=False)}})
print(patch)
" | xargs -0 -I{} kubectl patch configmap shturval-descheduler -n kube-system --type merge -p '{}'
```