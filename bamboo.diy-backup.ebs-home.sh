#!/bin/bash


function bamboo_prepare_home {
    # Validate that all the configuration parameters have been provided to avoid bailing out and leaving Bamboo locked
    if [ -z "${HOME_DIRECTORY_MOUNT_POINT}" ]; then
        error "The home directory mount point must be set as HOME_DIRECTORY_MOUNT_POINT in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${HOME_DIRECTORY_DEVICE_NAME}" ]; then
        error "The home directory volume device name must be set as HOME_DIRECTORY_DEVICE_NAME in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    BACKUP_HOME_DIRECTORY_VOLUME_ID=
    validate_ebs_volume "${HOME_DIRECTORY_DEVICE_NAME}" BACKUP_HOME_DIRECTORY_VOLUME_ID

    if [ -z "${BACKUP_HOME_DIRECTORY_VOLUME_ID}" ] || [ "${BACKUP_HOME_DIRECTORY_VOLUME_ID}" == null ]; then
        error "Device name ${HOME_DIRECTORY_DEVICE_NAME} specified in ${BACKUP_VARS_FILE} as HOME_DIRECTORY_DEVICE_NAME could not be resolved to a volume."

        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi
}

function bamboo_backup_home {
    # Freeze the home directory filesystem to ensure consistency
    freeze_home_directory
    # Add a clean up routine to ensure we unfreeze the home directory filesystem
    add_cleanup_routine unfreeze_home_directory

    info "Performing backup of home directory"

    snapshot_ebs_volume "${BACKUP_HOME_DIRECTORY_VOLUME_ID}" "Perform backup: ${PRODUCT} home directory snapshot"

    unfreeze_home_directory
}

function bamboo_prepare_home_restore {
    local SNAPSHOT_TAG="${1}"

    if [ -z "${BAMBOO_HOME}" ]; then
        error "The ${PRODUCT} home directory must be set as BAMBOO_HOME in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${BAMBOO_UID}" ]; then
        error "The ${PRODUCT} home directory owner account must be set as BAMBOO_UID in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${AWS_AVAILABILITY_ZONE}" ]; then
        error "The availability zone for new volumes must be set as AWS_AVAILABILITY_ZONE in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${RESTORE_HOME_DIRECTORY_VOLUME_TYPE}" ]; then
        error "The type of volume to create when restoring the home directory must be set as RESTORE_HOME_DIRECTORY_VOLUME_TYPE in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    elif [ "io1" == "${RESTORE_HOME_DIRECTORY_VOLUME_TYPE}" ] && [ -z "${RESTORE_HOME_DIRECTORY_IOPS}" ]; then
        error "The provisioned iops must be set as RESTORE_HOME_DIRECTORY_IOPS in ${BACKUP_VARS_FILE} when choosing 'io1' volume type for the home directory EBS volume"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${HOME_DIRECTORY_DEVICE_NAME}" ]; then
        error "The home directory volume device name must be set as HOME_DIRECTORY_DEVICE_NAME in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${HOME_DIRECTORY_MOUNT_POINT}" ]; then
        error "The home directory mount point must be set as HOME_DIRECTORY_MOUNT_POINT in ${BACKUP_VARS_FILE}"
        bail "See bamboo.diy-aws-backup.vars.sh.example for the defaults."
    fi

    check_mount_point "${HOME_DIRECTORY_MOUNT_POINT}"

    validate_device_name "${HOME_DIRECTORY_DEVICE_NAME}"

    RESTORE_HOME_DIRECTORY_SNAPSHOT_ID=
    validate_ebs_snapshot "${SNAPSHOT_TAG}" RESTORE_HOME_DIRECTORY_SNAPSHOT_ID
}

function bamboo_restore_home {
    info "Restoring home directory from snapshot ${RESTORE_HOME_DIRECTORY_SNAPSHOT_ID} into a ${RESTORE_HOME_DIRECTORY_VOLUME_TYPE} volume"

    restore_from_snapshot "${RESTORE_HOME_DIRECTORY_SNAPSHOT_ID}" "${RESTORE_HOME_DIRECTORY_VOLUME_TYPE}" \
    "${RESTORE_HOME_DIRECTORY_IOPS}" "${HOME_DIRECTORY_DEVICE_NAME}" "${HOME_DIRECTORY_MOUNT_POINT}"

    cleanup_locks ${BAMBOO_HOME}

    info "Performed restore of home directory snapshot"
}

function freeze_home_directory {
    freeze_mount_point ${HOME_DIRECTORY_MOUNT_POINT}
}

function unfreeze_home_directory {
    unfreeze_mount_point ${HOME_DIRECTORY_MOUNT_POINT}
}

function cleanup_old_home_snapshots {
    for snapshot_id in $(list_old_ebs_snapshot_ids); do
        info "Deleting old EBS snapshot ${snapshot_id}"
        delete_ebs_snapshot "${snapshot_id}"
    done
}
