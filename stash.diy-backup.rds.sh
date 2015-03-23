#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 home_snapshot_id database_snapshot_id database_instance_id"

    exit 99
else
    validate_rds_snapshot "${2}"
fi

function stash_prepare_db {
    # Validate that all the configuration parameters have been provided to avoid bailing out and leaving Stash locked
    if [ -z "${BACKUP_RDS_INSTANCE_ID}" ]; then
        error "The RDS instance id must be set in ${BACKUP_VARS_FILE}"
        bail "See stash.diy-backup.vars.sh.example for the defaults."
    fi
}

function stash_backup_db {
    info "Performing backup of RDS instance ${BACKUP_RDS_INSTANCE_ID}"

    snapshot_rds_instance "${BACKUP_RDS_INSTANCE_ID}" "${BACKUP_RDS_INSTANCE_ID}-${BACKUP_TIMESTAMP}"
}

function stash_restore_db {
    RESTORE_RDS_SNAPSHOT_ID="${1}"
    RESTORE_RDS_INSTANCE_ID="${2}"

    if [ -z "${RESTORE_RDS_INSTANCE_CLASS}" ]; then
        info "No restore instance class has been set in ${BACKUP_VARS_FILE}"
    fi

    if [ -z "${RESTORE_RDS_SUBNET_GROUP_NAME}" ]; then
        info "No restore subnet group has been set in ${BACKUP_VARS_FILE}"
    fi

    if [ -z "${RESTORE_RDS_SECURITY_GROUP}" ]; then
        info "No restore security group has been set in ${BACKUP_VARS_FILE}"
    fi

    restore_rds_instance "${RESTORE_RDS_INSTANCE_ID}" "${RESTORE_RDS_SNAPSHOT_ID}"

    info "Performed restore of ${RESTORE_RDS_SNAPSHOT_ID} to RDS instance ${RESTORE_RDS_INSTANCE_ID}"
}
