#!/bin/bash

SCRIPT_DIR=$(dirname $0)

# Contains util functions (bail, info, print)
source ${SCRIPT_DIR}/bamboo.diy-backup.utils.sh

# BACKUP_VARS_FILE - allows override for bamboo.diy-backup.vars.sh
if [ -z "${BACKUP_VARS_FILE}" ]; then
    BACKUP_VARS_FILE=${SCRIPT_DIR}/bamboo.diy-aws-backup.vars.sh
fi

# Declares other scripts which provide required backup/archive functionality
# Contains all variables used by the other scripts
if [[ -f ${BACKUP_VARS_FILE} ]]; then
    source ${BACKUP_VARS_FILE}
else
    error "${BACKUP_VARS_FILE} not found"
    bail "You should create it using ${SCRIPT_DIR}/bamboo.diy-aws-backup.vars.sh.example as a template"
fi

# Contains common functionality related to Bamboo
source ${SCRIPT_DIR}/bamboo.diy-backup.common.sh

# The following scripts contain functions which are dependent on the configuration of this bamboo instance.
# Generally each of them exports certain functions, which can be implemented in different ways

# Exports aws specific function to be used during the backup
source ${SCRIPT_DIR}/bamboo.diy-backup.ec2-common.sh

if [ "ebs-collocated" == "${BACKUP_DATABASE_TYPE}" ] || [ "rds" == "${BACKUP_DATABASE_TYPE}" ]; then
    # Exports the following functions
    #     bamboo_backup_db      - for making a backup of the bamboo DB
    source ${SCRIPT_DIR}/bamboo.diy-backup.${BACKUP_DATABASE_TYPE}.sh
else
    error "${BACKUP_DATABASE_TYPE} is not a supported AWS database backup type"
    bail "Please update BACKUP_DATABASE_TYPE in ${BACKUP_VARS_FILE} or consider running bamboo.diy-backup.sh instead"
fi

if [ "ebs-home" == "${BACKUP_HOME_TYPE}" ]; then
    # Exports the following functions
    #     bamboo_backup_home    - for making the actual filesystem backup
    source ${SCRIPT_DIR}/bamboo.diy-backup.${BACKUP_HOME_TYPE}.sh
else
    error "${BACKUP_HOME_TYPE} is not a supported AWS home backup type"
    bail "Please update BACKUP_HOME_TYPE in ${BACKUP_VARS_FILE} or consider running bamboo.diy-backup.sh instead"
fi

##########################################################
# The actual backup process. It has the following steps
bamboo_prepare_home
bamboo_prepare_db

# Locking the bamboo instance, starting an external backup and waiting for instance readiness
bamboo_lock
bamboo_backup_start
bamboo_backup_wait

# Backing up the database and reporting 50% progress
bamboo_backup_db
bamboo_backup_progress 50

# Backing up the filesystem and reporting 100% progress
bamboo_backup_home
bamboo_backup_progress 100

# Unlocking the bamboo instance
bamboo_unlock

success "Successfully completed the backup of your ${PRODUCT} instance"

##########################################################
# Clean up old backups, keeping just the most recent ${KEEP_BACKUPS} snapshots

cleanup_old_db_snapshots
cleanup_old_home_snapshots

