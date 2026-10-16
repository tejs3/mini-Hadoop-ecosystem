#!/bin/bash
set -e
HBASE_HOME=/usr/local/hbase
CONF=/tmp/hbase-conf
mkdir -p "$CONF"
cp /config/*.xml "$CONF/"
HOSTNAME_FQDN="${POD_NAME}.hbase-rs.hadoop.svc.cluster.local"
# inject regionserver hostname before closing configuration tag
grep -v '</configuration>' "$CONF/hbase-site.xml" > "$CONF/hbase-site.xml.tmp"
cat >> "$CONF/hbase-site.xml.tmp" <<EOF
  <property>
    <name>hbase.regionserver.hostname</name>
    <value>${HOSTNAME_FQDN}</value>
  </property>
</configuration>
EOF
mv "$CONF/hbase-site.xml.tmp" "$CONF/hbase-site.xml"
export HBASE_MANAGES_ZK=false
echo "RS hostname=$HOSTNAME_FQDN"
for i in $(seq 1 60); do
  if nc -z hbase-master 16000 2>/dev/null; then
    echo "master up"
    break
  fi
  echo "waiting master"
  sleep 5
done
exec "$HBASE_HOME/bin/hbase" --config "$CONF" regionserver start
