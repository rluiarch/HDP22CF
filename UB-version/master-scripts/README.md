## Master Script

This master script is intended to launch a HDP cluster on AWS from a defined CF template, and once all AWS nodes are up, the script will start the HDP cluster configuration setup via Ambari blueprint. And when the HDP cluster is totally running, it will install the custom UB software on the edge client node.

The expected output of this master script:

- A running HDP 2.4 cluster with one Ambari server, one master node, three worker nodes
- An edge client named as "gateway node" with 2nd drive (150GB) on empirical volume mounted on /data1
- All machines are on Centos7.2 , Oracle JDK 1.8, Ambai 2.2.1.1
- Install UB software on gateway node but not started and no instrumentation completed

## Preparation
To run this master script, please copy everything from this master-scripts folder to your AWS workstation /tmp folder. 

And requirement for AWS workstation:

- AWS CLI installed and configured to be us-east-1 region 
- necessary AWS permission or policy to create EC2, ASG , Read S3 ..etc
- curl, wget, unzip and jq
   
   ## jq can be installed from epel on centos or rhel 
   `` rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm ``

   `` yum install -y jq ``

- This AWS workstation need to be on the same VPC and subnet of the HDP cluster
- Save the private key on this AWS workstation, it is required to ssh to edge client to install UB software.


Before running the script, please modify HDP-custom-08.json file and ensure correct URL to download UB software. Search and replace the following line with the correct URL in your environment.

   `` "curl http://172.31.11.252:8000/ub-4.0-833.x86_64.rpm -o /tmp/ub-4.0-833.x86_64.rpm", ``

Additionally, the parameter-08.json file need to updated to reflect the correct parameters in your environment.

## Running the script

ssh to the configured AWS workstaion and run the following command

   ``/tmp/hdp-aw-master.sh  my-stakc-name``
