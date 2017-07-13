#!/bin/bash

recipients=""

backup_f () {

        echo " -------------------- `date +'%Y-%m-%d'` --------------------- "
        echo ""
        find /mnt/hdd_backup/vms/ -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;
        /sbin/lvcreate -l 100%FREE -s -n vmssnapshot /dev/mapper/ssd_vg-vms
        mount /dev/mapper/ssd_vg-vmssnapshot /mnt/snapshots/
        mkdir /mnt/hdd_backup/vms/`hostname`.`date +'%Y-%m-%d'`
        /usr/bin/rsync -rlpgoDv /mnt/snapshots/ /mnt/hdd_backup/vms/`hostname`.`date +'%Y-%m-%d'`/
        mail_f
        chmod -R 777 /mnt/hdd_backup/vms/`hostname`.`date +'%Y-%m-%d'`
        umount /mnt/snapshots
        /sbin/lvremove -f /dev/mapper/ssd_vg-vmssnapshot

}

mail_f () {

        if [ "$?" -eq 0 ]; then

                echo -e "All vms on `hostname` were successfully backup" |  mail -s "Internal VMS Backup: OK " -a "From:" ${recipients}

        else

                echo -e "There are erros during the backup on `hostname`" | mail -s "Internal VMS Backup: Errors" -a "From:" ${recipients}

        fi

}

backup_f
