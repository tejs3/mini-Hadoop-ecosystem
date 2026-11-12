#!/bin/bash
# Create app_logs on the running SolrCloud and print cluster status.
set -u
mkdir -p /opt/hadoop-lab/solr/scripts /tmp/part7
cp -f /tmp/part7/app_logs_schema.json /tmp/part7/add_fields.json /tmp/part7/index_app_logs.py /tmp/part7/queries.sh /opt/hadoop-lab/solr/scripts/
chmod 755 /opt/hadoop-lab/solr/scripts/queries.sh /opt/hadoop-lab/solr/scripts/index_app_logs.py

echo "=== PODS ==="
kubectl get pods -n hadoop -l app=solr -o wide

echo "=== CREATE ==="
kubectl exec -n hadoop solr-0 -- curl -s "http://localhost:8983/solr/admin/collections?action=DELETE&name=app_logs&wt=json" || true
echo
kubectl exec -n hadoop solr-0 -- curl -s "http://localhost:8983/solr/admin/collections?action=CREATE&name=app_logs&numShards=2&replicationFactor=2&maxShardsPerNode=2&wt=json"
echo

echo "=== SCHEMA ==="
kubectl cp /tmp/part7/add_fields.json hadoop/solr-0:/tmp/add_fields.json
kubectl exec -n hadoop solr-0 -- curl -s -X POST -H "Content-type: application/json" --data-binary @/tmp/add_fields.json "http://localhost:8983/solr/app_logs/schema"
echo

echo "=== FIELDS ==="
kubectl exec -n hadoop solr-0 -- curl -s "http://localhost:8983/solr/app_logs/schema/fields?wt=json" 

echo
echo "=== CLUSTER ==="
kubectl exec -n hadoop solr-0 -- curl -s "http://localhost:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=app_logs&wt=json"
echo
echo CREATE_DONE
