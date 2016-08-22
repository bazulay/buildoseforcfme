#!/bin/bash -x

source ./ose_deploy.conf

echo "Registering System"
subscription-manager register --username=$RHNUSER --password=$RHNPASSWORD
subscription-manager attach --pool=$POOLID
 
echo "enabling all the repos"
subscription-manager repos --disable="*"
subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.2-rpms"
 
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools
 
yum update -y
### Install utilites for quick and advanced installation"
yum -y install atomic-openshift-utils
 
yum install -y docker-1.9
mkdir /images
chmod a+rwx /images
 
sed -i 's|--selinux-enabled|--insecure-registry=172.30.0.0/16 --selinux-enabled|g' /etc/sysconfig/docker
 
if [ "`hostname -f`" == "$MASTERFQDN" ];
then
  ssh-keygen
  if [ -n "${MASTERFQDN}" ]; then
    echo "Copying keys to $MASTERFQDN"
    ssh-copy-id root@$MASTERFQDN
  fi
 
  if [ -n "${NODE1FQDN}" ]; then
    echo "Copying keys to $NODE1FQDN"
    ssh-copy-id root@$NODE1FQDN
    scp $(readlink -f $0) root@$NODE1FQDN:/root/
    ssh root@$NODE1FQDN "chmod +x /root/prepforose.sh && ./prepforose.sh"
    ssh root@$NODE1FQDN "init 6"
  fi
 
  if [ -n "${NODE2FQDN}" ]; then
    echo "Copying keys to $NODE2FQDN"
    ssh-copy-id root@$NODE2FQDN
    scp $(readlink -f $0)  root@$NODE2FQDN:/root/
    ssh root@$NODE2FQDN "chmod +x /root/prepforose.sh && ./prepforose.sh"
    ssh root@$NODE2FQDN "init 6"
  fi
 
  if [ -n "${NODE3FQDN}" ]; then
    echo "Copying keys to $NODE3FQDN"
    ssh-copy-id root@$NODE3FQDN
    scp $(readlink -f $0)  root@$NODE3FQDN:/root/
    ssh root@$NODE3FQDN "chmod +x /root/prepforose.sh && ./prepforose.sh"
    ssh root@$NODE3FQDN "init 6"
  fi
fi
 
echo "reboot master manually"
