# RT Helpdesk monitoring and recovery

## Environment

Prometheus and Grafana are deployed in the `helpdesk` Kubernetes environment on the application EC2 host. This is a single-node kind course-project deployment, not a high-availability monitoring service.

## Prometheus

The Prometheus scrape interval is 15 seconds.

Live checks confirmed:
- The Helpdesk scrape target was healthy.
- `up{job="helpdesk"}` returned `1` while the application was available.
- `helpdesk_database_up` returned `1` while PostgreSQL was available.
- Application request metrics were observed for health, readiness, version and ticket API requests.

The database alert is named `HelpdeskDatabaseUnavailable`. Its expression is:

`helpdesk_database_up{job="helpdesk"} == 0`

It uses severity `critical` and a 60-second pending period.

## Grafana

The provisioned Prometheus datasource and dashboard were verified.

- Dashboard title: RT Helpdesk
- Dashboard UID: `rt-helpdesk`
- Folder: DevOps Lab
- Dashboard path: `/d/rt-helpdesk/rt-helpdesk`

The dashboard has seven panels: reachable targets, database reachability, API request rate, API 5xx percentage, API P95 latency, API response status rate and API process resident memory.

Grafana is exposed internally through a Kubernetes ClusterIP service. Use an approved port-forward or SSH tunnel for access; do not expose it publicly as part of this project.

## Alert firing and recovery test

A controlled database outage and recovery test was completed on 25 November 2026 with approval.

1. Baseline database metric was `1` and the alert was inactive.
2. The PostgreSQL StatefulSet was temporarily scaled to zero.
3. Prometheus observed the database metric at `0`.
4. The alert entered the firing state after the configured 60-second pending period.
5. PostgreSQL was restored to one replica and its rollout completed.
6. The metric returned to `1` and the alert cleared.
7. Final checks confirmed the PostgreSQL pod was Running and Ready, and its original PVC remained Bound.

The test passed. The database was restored to its original replica count. The PVC was not deleted. External email or chat notifications are not configured.

## Persistence and backup recovery

The PostgreSQL pod replacement test confirmed that the same persistent volume claim remained Bound and all six live ticket records retained their count and fingerprint.

A PostgreSQL custom-format backup was also restored into a separate disposable PostgreSQL 16 environment. The restored records were inspected, and the live database was not overwritten.

Backup artifact: `backups/helpdesk/20261124T200325Z.dump`

The backup contained five records. The later live comparison contained six because a Jenkins smoke test created another ticket after the backup was taken. This difference reflects the backup time.

Never restore a test archive over the live database. Backup archives contain ticket data and must remain private.

## Scope and limitations

This deployment demonstrates application metrics, database alerting, Grafana visualization, persistent-volume behavior and a tested backup restore. It does not provide high availability, multi-region disaster recovery or external alert notifications.
