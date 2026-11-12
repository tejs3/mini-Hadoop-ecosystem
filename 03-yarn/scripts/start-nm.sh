#!/bin/bash
set -e
NM_FQDN="${POD_NAME}.nodemanager.hadoop.svc.cluster.local"
mkdir -p /tmp/yarn-conf
cp /config/*.xml /tmp/yarn-conf/

# rebuild yarn-site with resolvable NM hostname
grep -v '</configuration>' /tmp/yarn-conf/yarn-site.xml > /tmp/yarn-conf/yarn-site.xml.tmp || cp /tmp/yarn-conf/yarn-site.xml /tmp/yarn-conf/yarn-site.xml.tmp
# drop any old nodemanager.hostname / address / webapp lines we will replace
grep -v -E 'yarn.nodemanager.hostname|yarn.nodemanager.address|yarn.nodemanager.webapp.address|\$\{env.POD_IP\}' /tmp/yarn-conf/yarn-site.xml.tmp > /tmp/yarn-conf/yarn-site.xml.clean || true
# ensure file still has opening configuration if greps emptied too much
if ! grep -q '<configuration>' /tmp/yarn-conf/yarn-site.xml.clean 2>/dev/null; then
  cp /config/yarn-site.xml /tmp/yarn-conf/yarn-site.xml.clean
  grep -v '</configuration>' /tmp/yarn-conf/yarn-site.xml.clean > /tmp/y2
  grep -v -E 'yarn.nodemanager.hostname|yarn.nodemanager.address|yarn.nodemanager.webapp.address|\$\{env.POD_IP\}' /tmp/y2 > /tmp/yarn-conf/yarn-site.xml.clean || true
fi
grep -v '</configuration>' /tmp/yarn-conf/yarn-site.xml.clean > /tmp/yarn-conf/yarn-site.xml.tmp
cat >> /tmp/yarn-conf/yarn-site.xml.tmp <<EOF
  <property>
    <name>yarn.nodemanager.hostname</name>
    <value>${NM_FQDN}</value>
  </property>
  <property>
    <name>yarn.nodemanager.address</name>
    <value>${NM_FQDN}:0</value>
  </property>
  <property>
    <name>yarn.nodemanager.webapp.address</name>
    <value>0.0.0.0:8042</value>
  </property>
  <property>
    <name>yarn.nodemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
</configuration>
EOF
mv /tmp/yarn-conf/yarn-site.xml.tmp /tmp/yarn-conf/yarn-site.xml

export HADOOP_CONF_DIR=/tmp/yarn-conf
export YARN_CONF_DIR=/tmp/yarn-conf
echo "Starting NodeManager hostname=${NM_FQDN} podIP=${POD_IP}"
grep -A2 'yarn.nodemanager.hostname' /tmp/yarn-conf/yarn-site.xml
exec yarn nodemanager
