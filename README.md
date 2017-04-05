# HDP22CF
Hortonworks Hadoop 2.2 AWS CloudFormation 

change the following stack-name "rlui-HDP-T007" each time after repeatly using this command.
the following command need to run on an AWS CLI workstation which is configured on us-east-1; since only us-east-1 AMI is tested as of this written

aws cloudformation create-stack --stack-name rlui-HDP-T007 --template-body file:///home/ec2-user/HDP-test1KKHHJX.json --parameters file:///home/ec2-user/parameter.json --tags file:///home/ec2-user/tags.json --capabilities CAPABILITY_IAM | tee stack.json


When the this Cloudformation stack creation complete successfully; either via CLI or AWS GUI to check.

Run the following command on Ambari node 
