# HDP22CF
Hortonworks Hadoop 2.2 AWS CloudFormation 

aws cloudformation create-stack --stack-name rlui-HDP-T007 --template-body file:///home/ec2-user/HDP-test1KKHHJX.json --parameters file:///home/ec2-user/parameter.json --tags file:///home/ec2-user/tags.json --capabilities CAPABILITY_IAM | tee stack.json
