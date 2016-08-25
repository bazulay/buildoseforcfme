#!/bin/bash

source ./ose_deploy.conf

cd ~

function admin_login {
	echo "function admin_login: login as admin"
	oc login -u system:admin
}

function create_keys {
	echo "function create_keys: creating cert"
	CA=/etc/origin/master
	oadm ca create-server-cert \
		--signer-cert=$CA/ca.crt \
		--signer-key=$CA/ca.key \
		--signer-serial=$CA/ca.serial.txt \
		--hostnames='*.${SUBDOMAIN}' \
		--cert=cloudapps.crt \
		--key=cloudapps.key 
	cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem
}

function create_management_infra_project {
	echo "function create_management_infra_project"
	oc project management-infra
}

function handle_management_infra_permissions {
	echo "function handle_management_infra_permissions"
	oadm policy add-role-to-user -n management-infra admin -z management-admin
	oadm policy add-role-to-user -n management-infra management-infra-admin -z management-admin
	oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:management-infra:management-admin
	oadm policy add-scc-to-user privileged system:serviceaccount:management-infra:management-admin
}


function persist_management_infra_token {
	echo "function persist_management_infra_token"
	oc sa get-token -n management-infra management-admin > /root/cfme4token.txt
}


function handle_management_infra {
	echo "function handle_management_infra"
	create_management_infra_project
	handle_management_infra_permissions
	persist_management_infra_token
}


function create_metrics_deployer_service_account {
	echo "function create_metrics_deployer_service_account"
	oc create -f - <<API
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-deployer
secrets:
- name: metrics-deployer
API

}

function handle_metrics_permissions {
	echo "function handle_metrics_permissions"
	oadm policy add-role-to-user \
	    edit system:serviceaccount:openshift-infra:metrics-deployer
	oadm policy add-cluster-role-to-user \
	    cluster-reader system:serviceaccount:openshift-infra:heapster
	oc secrets new metrics-deployer nothing=/dev/null
}


function deploy_metrics {
	echo "function deploy_metrics"
	cp /usr/share/openshift/examples/infrastructure-templates/enterprise/metrics-deployer.yaml metrics-deployer.yaml
	oc new-app -f metrics-deployer.yaml \
	    -p HAWKULAR_METRICS_HOSTNAME=${HAWKULARFQDN} \
	    -p USE_PERSISTENT_STORAGE=false
}

function create_metrics_route {
	echo "function create_metrics_route"
	#TODO persistant volume
	oadm router management-metrics -n default \
		--credentials=/etc/origin/master/openshift-router.kubeconfig \
		--service-account=router \
		--ports='443:5000' \
		--selector="kubernetes.io/hostname=$MASTERFQDN" \
		--stats-port=1937 \
		--host-network=false
}



function handle_metrics {
	oc project openshift-infra
	create_metrics_deployer_service_account
	handle_metrics_permissions
	deploy_metrics
}

function handle_assets_config {
	echo "function handle_assets_config"
	sed "/assetConfig/s/assetConfig:/assetConfig:\n  metricsPublicURL: \"https\:\/\/$HAWKULARFQDN\/hawkular\/metrics\"/" -i /etc/origin/master/master-config.yaml
}

#admin_login
#create_keys
#handle_management_infra
#handle_metrics
#handle_assets_config
