#!/bin/bash

# Virtual Box Manager Init
vbox='/usr/bin/vboxmanage'

# Creating the running vms array
rvms=()
while read i

	do

		rvms+=( "$i" )

	done < <( ${vbox} list runningvms | awk -F "\"" '{print $2}' )

# Creating all vms array
avms=()
while read i

	do

		avms+=( "$i")

	done < <( ${vbox} list vms | awk -F "\"" '{print $2}' )

# Not running vms array
notrvms=()

# VMS fail stop, export, start arrays
vms_failed_stop=()
vms_failed_export=()
vms_failed_start=()

# Backup day
bckday=`date '+%Y-%m-%d'`

# Backup dir
bckdir='/mnt/backup'

# SAMBA share state
smb_state=`mount | grep //192.168.2.2/BACKUP/VM | awk '{print $6}'`

# E-mail recipients
recipients=""

# E-mail header
mail_from="From:"

# Generating the backup log day
echo "#--------------------------------------- ${bckday} ---------------------------------------#"

# Checking SAMBA share availability
if [ ${smb_state} != "(rw)" ]; then

	echo "The backup was not initiated due to samba share issue" | mail -s "Internal VMS Backup: Failure"  -a ${mail_from} ${recipients}
	exit 2

fi

# Keeping 7 days backup
find ${bckdir} -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# Array length controller
array_el=0

# Saving the vms state and exporting to samba share
while [ ${array_el} -lt ${#rvms[@]} ];

	do

		${vbox} controlvm "${rvms[$array_el]}" savestate

		if [ "$?" -eq 0 ]; then

			echo "The ${rvms[$array_el]} has been stopped...OK"

		elif [ "$?" -ne 0 ]; then

			echo "The ${rvms[$array_el]} hasnt been stopped...FAILURE"
			vms_failed_stop+=( "${rvms[$array_el]}" )
			(( array_el++ ))
			continue

		fi

		if [ ! -d "${bckdir}/${bckday}" ]; then

			mkdir ${bckdir}/${bckday}

		fi

		${vbox} export "${rvms[$array_el]}" -o ${bckdir}/${bckday}/"${rvms[$array_el]}".ova 

		case "$?" in

				'0')

					echo "The ${rvms[$array_el]} has been exported...OK"
					;;

				'*')

					echo "The ${rvms[$array_el]} hasnt been exported...FAILURE"
					vms_failed_export+=( "${rvms[$array_el]}" )
					;;

		esac

		(( array_el++ ))

	done

# Exporting not running vms
for i in "${avms[@]}"

	do

		counter=0

		for j in "${rvms[@]}"

			do

				if [ "$i" == "$j" ]; then

					(( counter++ ))
					break

				fi

			done

		if [ "${counter}" -eq 0 ]; then

			${vbox} export "$i" -o ${bckdir}/${bckday}/"$i".ova

			case "$?" in

				'0')

					notrvms+=( "$i" )
					echo "The $i has been exported...OK"
					;;

				'*')

					echo "The $i hasnt been exported...FAILURE"
					vms_failed_export+=( "$i" )
					;;

			esac

		fi

	done

# Re-Init Array length controller
array_el=0

# Starting the vms from saved states
while [ ${array_el} -lt ${#rvms[@]} ];

	do

		${vbox} startvm "${rvms[$array_el]}" --type headless

		case "$?" in

				'0')

					echo "The ${rvms[$array_el]} has been started...OK"
					;;

				'*')

					echo "The ${rvms[$array_el]} hasnt been started...FAILURE"
					vms_failed_start+=( "${rvms[$array_el]}" )
					;;

		esac

		(( array_el++ ))

	done

# Generating E-mail report
if 	[ ${#rvms_failed_stop[@]} -gt 0 ] || [ ${#rvms_failed_export[@]} -gt 0 ] || [ ${#rvms_failed_start[@]} -gt 0 ]; then

	echo -e " There are erros during the backup \n \n \
			VMS failed to stop: ${rvms_failed_stop[@]} \n \
			VMS failed to export: ${rvms_failed_export[@]} \n \
			VMS failed to start: ${rvms_failed_start[@]} " | mail -s "Internal VMS Backup: Errors" -a ${mail_from} ${recipients}

elif [ ${#rvms_failed_stop[@]} -eq 0 ] && [ ${#rvms_failed_export[@]} -eq 0 ] && [ ${#rvms_failed_start[@]} -eq 0 ]; then

	echo -e " All vms were successfully backup \n \n \
			Running VMS backup: ${rvms[@]} \n \
			Not running VMS backup: ${notrvms[@]} " | mail -s "Internal VMS Backup: OK " -a  ${mail_from} ${recipients}

fi
