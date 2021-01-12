#!/bin/bash

function check_status(){
    if [[ $? -eq 1 ]]
    then
        echo "Exiting: Command or check failed :("
        exit 1
    fi
}

[[ -e "${mount_device}" ]]
check_status

echo "${mount_device} exists and now will be updated!"
mkfs -t xfs ${mount_device}

if [[ ! -d "${mount_path}" ]]
then
    echo "${mount_path} doesn't exist and will be created"
    mkdir ${mount_path}   
fi

cp /etc/fstab /etc/fstab.ori.bak
echo "UUID=$(blkid | grep ${mount_device} | awk -F '"' '{print $2}') ${mount_path} xfs defaults,nofail 0 2" >> /etc/fstab

echo "Backing up ${mount_path} now..."
cp -R ${mount_path} /tmp/backup/
echo "Backup created"

mount -a
cp -Rf /tmp/backup/ ${mount_path}


if mountpoint -q ${mount_path}
then
   echo "${mount_path} mounted"
else
   echo "Error: ${mount_path} not mounted"
   exit 1
fi

yum update -y
yum install -y ${web_server}
systemctl start ${web_server}
systemctl enable ${web_server}