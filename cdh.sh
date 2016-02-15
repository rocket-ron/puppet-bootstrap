#!/usr/bin/env bash

log "BEGIN: master node deployments"

log "Beginning process of disabling SELinux"

log "Running as $(whoami) on $(hostname)"

# Use the Cloudera-documentation-suggested workaround
log "about to set setenforce to 0"
set +e
setenforce 0 >> /tmp/setenforce.out

exitcode=$?
log "Done with settiing enforce. Its exit code was $exitcode"

log "Running setenforce inline as $(setenforce 0)"

getenforce
log "Running getenforce inline as $(getenforce)"
getenforce >> /tmp/getenforce.out

log "should be done logging things"


cat /etc/selinux/config > /tmp/beforeSelinux.out
log "ABOUT to replace enforcing with disabled"
sed -i 's^SELINUX=enforcing^SELINUX=disabled^g' /etc/selinux/config || true

cat /etc/selinux/config > /tmp/afterSeLinux.out
log "Done disabling selinux"

set +e

log "Set cloudera-manager.repo to CM v5"
yum clean all >> /tmp/initialize-cloudera-server.log
rpm --import http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera >> /tmp/initialize-cloudera-server.log
wget http://archive.cloudera.com/cm5/redhat/6/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo >> /tmp/initialize-cloudera-server.log
# this often fails so adding retry logic
n=0
until [ $n -ge 5 ]
do
    yum install -y oracle-j2sdk* >> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err && break
    n=$[$n+1]
    sleep 15s
done
if [ $n -ge 5 ]; then log "scp error $remote, exiting..." & exit 1; fi

log "installing external DB"
sudo yum install postgresql-server -y

# Install CDH in pseudo-cluster mode
sudo yum install hadoop-conf-psuedo

# Format the Namenode
sudo -u hdfs hdfs namenode -format

# Start HDFS
for x in `cd /etc/init.d ; ls hadoop-hdfs-*` ; do sudo service $x start ; done

# Create directories required for hadoop processes
sudo /usr/lib/hadoop/libexec/init-hdfs.sh

