#!/bin/bash
set -e
unset SOLR_PORT SOLR_SERVICE_PORT SOLR_PORT_8983_TCP SOLR_PORT_8983_TCP_ADDR SOLR_SERVICE_HOST SOLR_SERVICE_PORT_HTTP || true
export SOLR_HOST="${POD_NAME}.solr-hs.hadoop.svc.cluster.local"
export SOLR_PORT=8983
mkdir -p /var/solr/data /var/solr/logs
if [ ! -f /var/solr/data/solr.xml ]; then
cat > /var/solr/data/solr.xml <<'XML'
<solr>
  <solrcloud>
    <str name="host">${host:}</str>
    <int name="hostPort">${jetty.port:8983}</int>
    <str name="hostContext">${hostContext:solr}</str>
    <int name="zkClientTimeout">${zkClientTimeout:30000}</int>
    <bool name="genericCoreNodeNames">${genericCoreNodeNames:true}</bool>
  </solrcloud>
</solr>
XML
fi
for i in $(seq 1 60); do
  if echo ruok | nc -w 2 zk-0.zk-hs.hadoop.svc.cluster.local 2181 2>/dev/null | grep -q imok; then
    echo "ZK ready"
    break
  fi
  sleep 5
done
echo "SOLR_HOST=$SOLR_HOST ZK_HOST=$ZK_HOST"
exec solr-fg -cloud -z "$ZK_HOST" -p 8983 --force
