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

sudo rm -rf /tmp/kerberos_clients

echo -e "\n Internal DNS Names of all nodes in this AWS HDP cluster ${1}"
echo " "
for NODE in AmbariNode MasterNode GatewayNode WorkerNodes; do
   NODEPRIDNS=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=${NODE}" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text | tr '\n' ','`

  echo "${NODE} PrivateDNS Name = ${NODEPRIDNS}"
  echo -n ${NODEPRIDNS} >> /tmp/kerberos_clients
done

echo " "

KERBEROS_NODE=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=KerberosNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`

KERBEROS_IP=`echo ${KERBEROS_NODE} |cut -d"." -f1 |cut -d"-" -f2-5 |sed -e 's/\-/\./g'`

echo "KerberosNode PrivateDNS Name = ${KERBEROS_NODE}"
echo "KerberosNode Private IP address is ${KERBEROS_IP}"

AMBARI_HOST=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=AmbariNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`


# Remove the old hdp-install script on AWS workstation temp folder

sudo rm -rf /tmp/hdp-install-*.sh

curl https://raw.githubusercontent.com/rluiarch/HDP22CF/master/UB-version/KerberosHDP/hdp-install-10.sh -o /tmp/hdp-install-10.sh

sudo chmod a+x /tmp/hdp-install-10.sh

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

GATEWAY_NODE=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=GatewayNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`

GATEWAY_IP=`echo ${GATEWAY_NODE} |cut -d"." -f1 |cut -d"-" -f2-5 |sed -e 's/\-/\./g'`

echo -e "\n The Gateway node IP address is ${GATEWAY_IP}"

ssh -t -oStrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'hostname; ls -al /tmp/*.rpm ; sudo rpm -U /tmp/ub-4.0-860.x86_64.rpm'

echo "all tasks in hdp-aws-master.sh script are completed"
echo -e "\n starting UnRavelData instremenation on HDP"

ssh -t -oStrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'hostname; sudo /etc/init.d/unravel_all.sh stop'

sleep 15




# Kerberoize HDP

# clean up old stuff from previous run
sudo rm -rf /tmp/hdp_kerberized.sh
sudo rm -rf /tmp/payload
sudo rm -rf /tmp/payload_credential
sudo rm -rf /tmp/unravel.headless.keytab

echo -e "\n Setup kerberos HDP"
echo -e "\n Kerberoize HDP will take 15-20+ minutes, please wait"
curl https://raw.githubusercontent.com/rluiarch/HDP22CF/master/UB-version/KerberosHDP/hdp_kerberized.sh -o /tmp/hdp_kerberized.sh
sudo chmod a+x /tmp/hdp_kerberized.sh

/tmp/hdp_kerberized.sh ${1} > /tmp/hdp_kerberized_`date +%Y%m%d-%H:%M:%S`.log 

echo -e "\n Kerberoized HDP is completed"

echo -e "\n Start adding Unravel headless service principal"

ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${KERBEROS_NODE} "hostname; echo 'ank +needchange -pw abc123 unravel-${1}@EC2.INTERNAL' | sudo /usr/sbin/kadmin.local -p admin/admin@EC2.INTERNAL -w adbc123"

ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${KERBEROS_NODE} "hostname; echo 'xst -k /tmp/unravel.headless.keytab unravel-${1}@EC2.INTERNAL' | sudo /usr/sbin/kadmin.local -p admin/admin@EC2.INTERNAL -w adbc123"

ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${KERBEROS_NODE} 'sudo chmod 777 /tmp/unravel.headless.keytab'
ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${KERBEROS_NODE} 'sudo cp -p -r  /tmp/unravel.headless.keytab /home/centos/'


/usr/bin/scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null centos@${KERBEROS_IP}:unravel.headless.keytab /tmp
/usr/bin/scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/unravel.headless.keytab centos@${GATEWAY_IP}:/tmp/

ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'sudo cp /tmp/unravel.headless.keytab /etc/security/keytabs/'
ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'sudo chown unravel:hadoop /etc/security/keytabs/unravel.headless.keytab'
ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'sudo chmod 440 /etc/security/keytabs/unravel.headless.keytab'

# Update /usr/local/unravel/etc/unravel.ext.sh on Gateway Node

echo -e "\n Updating Unravel configuration "

ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'echo "export HDFS_KEYTAB_PATH=/etc/security/keytabs/hdfs.headless.keytab" | sudo tee -a /usr/local/unravel/etc/unravel.ext.sh'
ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} "echo 'export HDFS_KERBEROS_PRINCIPAL=hdfs-${1}@EC2.INTERNAL' | sudo tee -a /usr/local/unravel/etc/unravel.ext.sh"

# udpate /usr/local/unravel/etc/unravel.properties

ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'echo "HDFS_KEYTAB_PATH=/etc/security/keytabs/hdfs.headless.keytab" | sudo tee -a /usr/local/unravel/etc/unravel.properties'
ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} "echo 'HDFS_KERBEROS_PRINCIPAL=hdfs-${1}@EC2.INTERNAL' | sudo tee -a /usr/local/unravel/etc/unravel.properties"

ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} "echo 'com.unraveldata.kerberos.principal=unravel-${1}@EC2.INTERNAL' | sudo tee -a /usr/local/unravel/etc/unravel.properties"
ssh -t -o StrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} "echo 'com.unraveldata.kerberos.keytab.path=/etc/security/keytabs/unravel.headless.keytab' | sudo tee -a /usr/local/unravel/etc/unravel.properties"

echo -e "\n Completed Unravel Kerbero service setup"


# Installing UnRavelData Software on Gateway Node

#GATEWAY_IP=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=GatewayNode" "Name=tag:aws:cloudformation:stack-name,Values=${1}" --query "Reservations[].Instances[].[PrivateDnsName]" --output text`

#ssh -t -oStrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'hostname; ls -al /tmp/*.rpm ; sudo rpm -U /tmp/ub-4.0-860.x86_64.rpm'

#echo "all tasks in hdp-aws-master.sh script are completed"
#echo -e "\n starting UnRavelData instremenation on HDP"

#ssh -t -oStrictHostKeyChecking=no -oBatchMode=yes centos@${GATEWAY_IP} 'hostname; sudo /etc/init.d/unravel_all.sh stop'
