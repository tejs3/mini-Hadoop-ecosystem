#!/usr/bin/env bash
export JAVA_HOME=${JAVA_HOME:-/opt/java/openjdk}
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-/opt/hadoop/etc/hadoop}
export YARN_CONF_DIR=${YARN_CONF_DIR:-/opt/hadoop/etc/hadoop}
export SPARK_DIST_CLASSPATH=$(hadoop classpath 2>/dev/null || true)
