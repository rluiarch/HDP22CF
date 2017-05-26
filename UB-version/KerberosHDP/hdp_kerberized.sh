#!/bin/bash

yum install -y  moreutils

cluster_name=${1}

ambari_host=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=AmbariNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`

KDC_HOST=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=KerberosNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`

KERBEROS_CLIENTS=`cat /tmp/kerberos_clients |sed -e 's/.$//'`

REALM=EC2.INTERNAL

echo "cluster_name is ${cluster_name}"
echo "ambari_host is ${ambari_host}"
echo "KERBEROS_CLIENTS is ${KERBEROS_CLIENTS}"

echo " "

## Create payload

create_payload()
{
 echo "[
  {
    \"Clusters\": {
      \"desired_config\": {
        \"type\": \"krb5-conf\",
        \"tag\": \"version1\",
        \"properties\": {
          \"domains\":\"\",
          \"manage_krb5_conf\": \"true\",
          \"conf_dir\":\"/etc\",
          \"content\" : \"[libdefaults]\n  renew_lifetime = 7d\n  forwardable= true\n  default_realm = {{realm|upper()}}\n  ticket_lifetime = 24h\n  dns_lookup_realm = false\n  dns_lookup_kdc = false\n  #default_tgs_enctypes = {{encryption_types}}\n  #default_tkt_enctypes ={{encryption_types}}\n\n{% if domains %}\n[domain_realm]\n{% for domain in domains.split(',') %}\n  {{domain}} = {{realm|upper()}}\n{% endfor %}\n{%endif %}\n\n[logging]\n  default = FILE:/var/log/krb5kdc.log\nadmin_server = FILE:/var/log/kadmind.log\n  kdc = FILE:/var/log/krb5kdc.log\n\n[realms]\n  {{realm}} = {\n    admin_server = {{admin_server_host|default(kdc_host, True)}}\n    kdc = {{kdc_host}}\n }\n\n{# Append additional realm declarations below #}\n\"
        }
      }
    }
  },
  {
    \"Clusters\": {
      \"desired_config\": {
        \"type\": \"kerberos-env\",
        \"tag\": \"version1\",
        \"properties\": {
          \"kdc_type\": \"mit-kdc\",
          \"manage_identities\": \"true\",
          \"install_packages\": \"true\",
          \"encryption_types\": \"aes des3-cbc-sha1 rc4 des-cbc-md5\",
          \"realm\" : \"$REALM\",
          \"kdc_host\" : \"$KDC_HOST\",
          \"admin_server_host\" : \"$KDC_HOST\",
          \"executable_search_paths\" : \"/usr/bin, /usr/kerberos/bin, /usr/sbin, /usr/lib/mit/bin, /usr/lib/mit/sbin\",
          \"password_length\": \"20\",
          \"password_min_lowercase_letters\": \"1\",
          \"password_min_uppercase_letters\": \"1\",
          \"password_min_digits\": \"1\",
          \"password_min_punctuation\": \"1\",
          \"password_min_whitespace\": \"0\",
          \"service_check_principal_name\" : \"${cluster_name}-${short_date}\",
          \"case_insensitive_username_rules\" : \"false\"
        }
      }
    }
  }
]" > /tmp/payload
}
## Create payload_credential

create_payload_credential()

{
  echo "{
  \"session_attributes\" : {
    \"kerberos_admin\" : {
      \"principal\" : \"admin/admin@${REALM}\",
      \"password\" : \"abc123\"
    }
  },
  \"Clusters\": {
    \"security_type\" : \"KERBEROS\"
  }
}" > /tmp/payload_credential
}

create_payload
sleep 5
create_payload_credential

##Add the KERBEROS Service to cluster
echo -e "\n Adding KERBEROS Service to cluster"
curl -H "X-Requested-By:ambari" -u admin:admin -i -X POST http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/KERBEROS
sleep 3

## Add the KERBEROS_CLIENT component to the KERBEROS service
echo -e "\n Adding KERBEROS_CLIENT component to the KERBEROS service"
curl -H "X-Requested-By:ambari" -u admin:admin -i -X POST http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/KERBEROS/components/KERBEROS_CLIENT
sleep 3

## Create and set KERBEROS service configurations
curl -H "X-Requested-By:ambari" -u admin:admin -i -X PUT -d @/tmp/payload http://${ambari_host}:8080/api/v1/clusters/${cluster_name}
sleep 3

## Create the KERBEROS_CLIENT host components
echo -e "\n  Creating the KERBEROS_CLIENT host components for each HDP server and client"


for KCLIENT in `echo ${KERBEROS_CLIENTS} |sed -e 's/,/ /g'`; do
    echo $KCLIENT
    echo "curl -H "X-Requested-By:ambari" -u admin:admin -i -X POST -d '{"host_components" : [{"HostRoles" : {"component_name":"KERBEROS_CLIENT"}}]}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/hosts?Hosts/host_name=${KCLIENT}"
    curl -H "X-Requested-By:ambari" -u admin:admin -i -X POST -d '{"host_components" : [{"HostRoles" : {"component_name":"KERBEROS_CLIENT"}}]}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/hosts?Hosts/host_name=${KCLIENT}
    sleep 2
done


## Install the KERBEROS service and components
echo -e "\n Installing the KERBEROS service and components"

curl -H "X-Requested-By:ambari" -u admin:admin -i -X PUT -d '{"ServiceInfo": {"state" : "INSTALLED"}}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/KERBEROS

echo -e "\n Wait for 1 minute"
sleep 60

## Stop all services
echo -e "\n Stopping all the services"

curl -H "X-Requested-By:ambari" -u admin:admin -i -X PUT -d '{"ServiceInfo": {"state" : "INSTALLED"}}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services

echo -e "\n Wait for 3 minutes"
sleep 180




## Enabling kerberos service
echo -e "\n Enabling Kerberos"
curl -H "X-Requested-By:ambari" -u admin:admin -i -X PUT -d @/tmp/payload_credential http://${ambari_host}:8080/api/v1/clusters/${cluster_name}

echo -e "\n Starting all services after 2 minutes wait"
sleep 120

## Starting all services
echo -e "\n Begin start all services and will take up to 5+ minutes"
curl -H "X-Requested-By:ambari" -u admin:admin -i -X PUT -d '{"ServiceInfo": {"state" : "STARTED"}}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services
sleep 300
echo -e "\n Please check Ambari and Kerberos"

