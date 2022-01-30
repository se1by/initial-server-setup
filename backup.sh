#!/usr/bin/env bash

LOG="/var/log/borg/backup.log"

BORG_USER="__REPLACE_ME__"
BORG_PASSPHRASE="__REPLACE_ME__"
BORG_DIR="__REPLACE_ME__"

REPOSITORY="ssh://${BORG_USER}@${BORG_USER}.your-storagebox.de:23/./Borg/${BORG_DIR}"

exec > >(tee -i ${LOG})
exec 2>&1

echo "###### Backup started: $(date) ######"

borg create -v --stats                   \
	$REPOSITORY::'{now:%Y-%m-%d_%H:%M}'  \
	/root                                \
	/etc                                 \
	/var                                 \
	/opt                                 \
	/home                                \
	--exclude /dev                       \
	--exclude /proc                      \
	--exclude /sys                       \
	--exclude /var/run                   \
	--exclude /run                       \
	--exclude /lost+found                \
	--exclude /mnt                       \
	--exclude /var/lib/lxcfs

echo "Pruning old backups ..."
borg prune -v --list $REPOSITORY --keep-within=1d --keep-daily=7 --keep-weekly=4 --keep-monthly=12

echo "###### Backup finished: $(date) ######"
