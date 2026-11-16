# grafinya s95-import CronJob (no git in `grafinya/`)

Apply in the grafinya Helm chart when deploying:

- `failedJobsHistoryLimit: 1`
- `successfulJobsHistoryLimit: 3`
- `jobTemplate.spec.ttlSecondsAfterFinished: 86400`

Path: `templates/s95-import-cronjob.yaml`