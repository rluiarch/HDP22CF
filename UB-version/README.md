This version of CF template will use existing

- VPC
- subnet
- security group
- IAM role
- availability zone

The IAM role required for this template should have S3 and EC2 access permissions

The CF template ended with 03 is configured to use RHEL 6.6 and Ambari 2.1.2 and HDP 2.2, and HDP setup require the hdp-install.sh 

The CF template ended with 04 is configured to use Centos 7.2 and Ambari 2.2.1.0 and HDP 2.2, and HDP setup will require hdp-install-04.sh

## launch the CF stack

From the configured AWS CLI workstation, run the following aws command

    aws cloudformation create-stack --stack-name rlui-HDP-T007   \ 
        --template-body file:///root/CF_template_UB_work/HDP-custom-04.json \
        --parameters file:///root/CF_template_UB_work/parameter-04.json     \
        --tags file:///root/CF_template_UB_work/tags.json --capabilities    \
        CAPABILITY_IAM | tee stack.json


## Setup up HDP clutser
The HDP cluster name will use the stack name e.g. STACKNAME=rlui-HDP-T007
   you can retrieve the stack name from AWS CLI workstation e.g.
   
   ``aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE |grep StackName |grep rlui |awk '{print $2}' |tr -d '"' |tr -d ','``
    
 ssh into the Ambrai node (m4.large instance); and become root and run the following command
    
   ``curl https://raw.githubusercontent.com/rluiarch/HDP22CF/master/UB-version/hdp-install-04.sh -o hdp-install-04.sh``
   
   ``chmod +x hdp-install-04.sh``
   
   ``ambari_host=`hostname` cluster_name=rlui-HDP-T007 ./hdp-install-04.sh``
   
   You will be asked to provide your AWS Key/Secret; since hdp-install.sh use AWS CLI to retrieve all stack component information, and then using sed and jq to assamble the Ambari cluster blue print.
   
Login into Ambari node console http://<ambrai_node_IP_Address>:8080  
Default ID/Password for Ambari is admin/admin

Wait until Ambari finish installing the cluster will take about 10-15 min
