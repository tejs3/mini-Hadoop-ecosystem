#!/bin/bash
# Bring up the full Part-1 Hadoop ecosystem on Kind (idempotent).
set -euo pipefail
BASE=/opt/hadoop-lab
NS=hadoop

echo "[1/8] Ensure namespace"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

echo "[2/8] Refresh ConfigMaps / scripts"
kubectl -n "$NS" create configmap hdfs-config \
  --from-file="$BASE/hdfs/conf/core-site.xml" \
  --from-file="$BASE/hdfs/conf/hdfs-site.xml" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" create configmap yarn-config \
  --from-file="$BASE/yarn/conf/" \
  --dry-run=client -o yaml | kubectl apply -f - || true

kubectl -n "$NS" create configmap hbase-config \
  --from-file="$BASE/hbase/conf/hbase-site.xml" \
  --from-file="$BASE/hdfs/conf/core-site.xml" \
  --from-file="$BASE/hdfs/conf/hdfs-site.xml" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" create configmap hbase-scripts \
  --from-file="$BASE/hbase/scripts/start-master.sh" \
  --from-file="$BASE/hbase/scripts/start-rs.sh" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" create configmap solr-scripts \
  --from-file="$BASE/solr/scripts/start-solr.sh" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[3/8] HDFS"
kubectl apply -f "$BASE/hdfs/manifests/"

echo "[4/8] YARN"
kubectl apply -f "$BASE/yarn/manifests/"

echo "[5/8] ZooKeeper"
kubectl apply -f "$BASE/zookeeper/manifests/"
kubectl rollout status statefulset/zk -n "$NS" --timeout=300s || true

echo "[6/8] Kafka"
kubectl apply -f "$BASE/kafka/manifests/"

echo "[7/8] HBase + Solr"
kubectl apply -f "$BASE/hbase/manifests/"
kubectl apply -f "$BASE/solr/manifests/"

echo "[8/8] Status"
kubectl get pods,svc -n "$NS" -o wide
echo "Bring-up complete."
