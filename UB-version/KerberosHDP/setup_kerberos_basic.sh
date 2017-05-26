#!/bin/bash

ts()
{
  echo "`date +%Y-%m-%d,%H:%M:%S`"
}

REALM=EC2.INTERNAL
KDC_HOST=`hostname -f`
KDC_PASS=abc123

sed -i "s/EXAMPLE.COM/${REALM}/g" /etc/krb5.conf
sed -i "s/kerberos.example.com/${KDC_HOST}/g" /etc/krb5.conf
cd /tmp/haveged-1.9.1 && ./configure && make && make install

haveged -w 1024

kdb5_util create -s -P ${KDC_PASS}

echo -e "\n `ts` Starting KDC services"

systemctl start krb5kdc
systemctl start kadmin

kadmin.local -q "addprinc -pw abc123 admin/admin@${REALM}"

sleep 10

echo ${REALM}
sed -i "s/EXAMPLE.COM/${REALM}/g" /var/kerberos/krb5kdc/kadm5.acl
echo "admin/admin@EC2.INTERNAL    *" >> /var/kerberos/krb5kdc/kadm5.acl

systemctl restart kadmin
