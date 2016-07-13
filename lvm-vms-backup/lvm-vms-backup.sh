#!/bin/bash

echo " -------------------- `date +'%Y-%m-%d'` --------------------- "
echo ""
find /mnt/hdd_backup/vms/ -maxdepth 1 -type d -mtime +21 -exec rm -rf {} \;
/sbin/lvcreate -l 100%FREE -s -n vmssnapshot /dev/mapper/ssd_vg-vms
mount /dev/mapper/ssd_vg-vmssnapshot /mnt/snapshots/
mkdir /mnt/hdd_backup/vms/`date +'%Y-%m-%d'`
/usr/bin/rsync -av /mnt/snapshots/ /mnt/hdd_backup/vms/`date +'%Y-%m-%d'`
chmod -R 777 /mnt/hdd_backup/vms/`date +'%Y-%m-%d'`
umount /mnt/snapshots
/sbin/lvremove -f /dev/mapper/ssd_vg-vmssnapshot