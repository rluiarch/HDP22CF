# HDP22CF
Hortonworks Hadoop 2.2 AWS CloudFormation 

This cloudformation template will setup 4 node HDP cluster with  RHEL6.6 + Ambari 2.1.2 + HDP2.2

# Component of this cluster
--Ambari node        1 X m4.large
--HDP Master node    1 X m4.xlarge
--HDP Worker node    2 X m4.xlarge

# Running the CF template
change the following stack-name "rlui-HDP-T007" each time after repeatly using this command.
You may want to update the parameter.json to change the instance type corresponding to HDP master and worker nodes.
the following command need to run on an AWS CLI workstation which is configured on us-east-1; since only us-east-1 AMI is tested as of this written

``aws cloudformation create-stack --stack-name rlui-HDP-T007 --template-body file:///home/ec2-user/HDP-test1KKHHJX.json --parameters file:///home/ec2-user/parameter.json --tags file:///home/ec2-user/tags.json --capabilities CAPABILITY_IAM | tee stack.json``

When the this Cloudformation stack creation complete successfully; either via CLI or AWS GUI to check.
the Cloudformation will take about 20-25 min for this setup.

# Setup up HDP clutser
The HDP cluster name will use the stack name e.g. STACKNAME=rlui-HDP-T007
   you can retrieve the stack name from AWS CLI workstation e.g.
   
   ``aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE |grep StackName |grep rlui |awk '{print $2}' |tr -d '"' |tr -d ','``
    
 ssh into the Ambrai node (m4.large instance); and become root and run the following command
    
   ``curl https://raw.githubusercontent.com/rluiarch/HDP22CF/master/hdp-install.sh -o hdp-install.sh``
   
   ``chmod +x hdp-install.sh``
   
   ``ambari_host=`hostname` cluster_name=rlui-HDP-T007 ./hdp-install.sh``
   
   You will be asked to provide your AWS Key/Secret; since hdp-install.sh use AWS CLI to retrieve all stack component information, and then using sed and jq to assamble the Ambari cluster blue print.
   
Login into Ambari node console http://<ambrai_node_IP_Address>:8080  
Default ID/Password for Ambari is admin/admin

Wait until Ambari finish installing the cluster will take about 15-20 min


   

