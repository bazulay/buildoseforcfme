#!/bin/bash
# Create an OSEv3 group that contains the masters and nodes groups

source ./ose_deploy.conf
 
cd ~
 
echo "Writing Ansible HOSTS File"
cat <<EOF | tee /etc/ansible/hosts
[OSEv3:children]
masters
nodes
nfs
 
# Set variables common for all OSEv3 hosts
[OSEv3:vars]
# SSH user, this user should allow ssh based auth without requiring a password
ansible_ssh_user=root
osm_default_subdomain=$SUBDOMAIN
 
# If ansible_ssh_user is not root, ansible_sudo must be set to true
#ansible_sudo=true
 
deployment_type=openshift-enterprise
 
# uncomment the following to enable htpasswd authentication; defaults to DenyAllPasswordIdentityProvider
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/htpasswd'}]
 
# host group for masters
[masters]
$MASTERFQDN
 
# host group for nodes, includes region info
[nodes]
$MASTERFQDN openshift_node_labels="{'region': 'infra', 'zone': 'default'}" openshift_scheduleable=True
$NODE1FQDN openshift_node_labels="{'region': 'apps', 'zone': 'east'}"
$NODE2FQDN openshift_node_labels="{'region': 'apps', 'zone': 'west'}"
$NODE3FQDN openshift_node_labels="{'region': 'apps', 'zone': 'west'}"

${NFS}
EOF
 
echo "Running Asible"
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
 
