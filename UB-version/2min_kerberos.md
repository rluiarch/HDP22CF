## Create a kerberos server in 2 minutes

### Step 1

    yum install krb5-server krb5-libs krb5-workstation


### Step 2

Update the /etc/krb5.conf file, includes the following lines ; or update your own version with correct domain name

     default_realm = EC2.INTERNAL

    [realms]
     EC2.INTERNAL = {
       kdc = ip-172-31-11-252.ec2.internal
       admin-server = ip-172-31-11-252.ec2.internal
      }

## Step 3

start KDC server

    kdb5_util create -s

The  above step may take very long time due to not enough entropy , do the followings

    yum install -y gcc-c++ 
    wget http://www.issihosts.com/haveged/haveged-1.9.1.tar.gz
    tar -zxvf haveged-1.9.1.tar.gz
    cd haveged-1.9.1
    ./configure
    make
    make install
    haveged -w 1024

Then redo   ``kdb5_util create -s``

    systemctl start krb5kdc
    systemctl start kadmin


## Step 4

Create KDC admin principal

		kadmin.local -q "addprinc admin/admin"

enter the key or password for admin principal, e.g. password

      cat /var/kerberos/krb5kdc/kadm5.acl

should show admin has * permission


