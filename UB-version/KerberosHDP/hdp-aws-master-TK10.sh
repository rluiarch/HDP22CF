#!/bin/bash


aws cloudformation create-stack --stack-name $1 --template-body file:///tmp/HDP-custom-k10.json --parameters file:///tmp/parameter-10.json --tags file:///tmp/tags.json  --capabilities CAPABILITY_IAM | tee stack-${1}.json

sleep 2
## Wait until cluster is up.
echo "AWS HDP Cluster is setting up now, please wait,it will takes up to 15-20 minutes"
echo "The CF Stackname is ${1}"

last_status=

while [ "$last_status" != "CREATE_COMPLETE" ]; do
      sleep 15
      status=`aws cloudformation describe-stacks --stack-name $1 |grep "StackStatus" |tr -d '"' |tr -d ',' |awk '{ print $2 }'`
      echo -n "."
      last_status=$status
      if [ "$status" != "CREATE_IN_PROGRESS" ]; then
         echo " done"
         echo -n "$status"
      fi
done

echo -e "\n AWS HDP cluster creation is completed"
echo " "
echo -e "\n Public DNS Names of all nodes in this AWS HDP cluster ${1}"
echo " "


for NODE in AmbariNode MasterNode GatewayNode WorkerNodes KerberosNode; do
   NODEPUBDNS=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=${NODE}" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PublicDnsName]" --output text | tr '\n' ' '`
   echo "${NODE} PublicDNS Name = ${NODEPUBDNS}"
done

rm -rf /tmp/kerberos_clients

echo -e "\n Internal DNS Names of all nodes in this AWS HDP cluster ${1}"
echo " "
for NODE in AmbariNode MasterNode GatewayNode WorkerNodes; do
   NODEPRIDNS=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=${NODE}" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text | tr '\n' ','`

  echo "${NODE} PrivateDNS Name = ${NODEPRIDNS}"
  echo -n ${NODEPRIDNS} >> /tmp/kerberos_clients
done

echo " "

KERBEROS_NODE=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=KerberosNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text | tr '\n' ' '`

echo "KerberosNode PrivateDNS Name = ${KERBEROS_NODE}"

AMBARI_HOST=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=AmbariNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`


echo "ambari_host=${AMBARI_HOST} cluster_name=${1} /tmp/hdp-install-10.sh"
ambari_host=${AMBARI_HOST} cluster_name=${1} /tmp/hdp-install-10.sh

echo -e "\n Ambari HDP cluster setup is started, it will takes 10-15 minutes to complete, please wait"

AMBARI_PHOST=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=AmbariNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PublicDnsName]" --output text`


last_Astatus=

while [ "$last_Astatus" != "COMPLETED" ]; do
      sleep 15
      Astatus=`curl -su admin:admin -H X-Requested-By:ambari http://${AMBARI_PHOST}:8080/api/v1/clusters/${1}/requests/1 | jq '.Requests' |grep "request_status" |tr -d '"' |tr -d ',' |awk '{print $2}'`
      echo -n "#"
      last_Astatus=$Astatus
      if [ "$Astatus" != "IN_PROGRESS" ]; then
         echo " done"
         echo -n "$Astatus"
      fi
done

echo -e "\n Ambari HDP cluster setup is completed"
echo -e "\n Please check Ambari cluster status at http://${AMBARI_PHOST}:8080"


# Installing UnRavelData Software on Gateway Node

GATEWAY_IP=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=GatewayNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`

ssh -t -oStrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'hostname; ls -al /tmp/*.rpm ; sudo rpm -U /tmp/ub-4.0-860.x86_64.rpm'

echo "all tasks in hdp-aws-master.sh script are completed"
echo -e "\n starting UnRavelData instremenation on HDP"

ssh -t -oStrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'hostname; sudo /etc/init.d/unravel_all.sh stop'
