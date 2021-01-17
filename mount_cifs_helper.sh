#!/bin/bash

ROOT_MEDIA="/media"

echo -n "Server: "
read SERVER

echo -n "Share: "
read SHARE

echo -n "User: "
read SMB_USER

echo -n "Password: "
stty -echo
# printf "Password: "
read SMB_PASS
stty echo
echo

MOUNT_POINT="${ROOT_MEDIA}/${SERVER}/${SHARE}"
echo -n "Accept generated mount point: "
echo "${MOUNT_POINT}"

echo -n "Accept mounting user. "
echo -n "=> "
id -a
echo

echo "Mount Read-Only or Read-Write"
echo "1. RO"
echo "2. RW"
echo -n "Choice: "
read CHOICE

case $CHOICE in
    1)
        RORW="ro"
        ;;
    2)
        RORW="rw"
        ;;
    *)
        RORW="ro"
        ;;
esac

echo

sync

if [ $(id -u) != 0 ]; then
    echo "Upgrade with sudo..."
    sudo id -a
fi

echo "Check if already mounted..."
if [ $(mount | grep -c ${MOUNT_POINT}) -eq 0 ]; then

    if [ ! -d "${MOUNT_POINT}" ]; then
        echo "Creating ${MOUNT_POINT}"
        sudo mkdir -p ${MOUNT_POINT}
    fi

    echo -n "Mounting //${SERVER}/${SHARE} as ${SMB_USER} to ${MOUNT_SANDRA} for "
    id -a
    echo

    sudo \
        mount -t cifs \
            -o $RORW,username=${SMB_USER},password=${SMB_PASS},uid=$(id -u),gid=$(id -g) \
            //${SERVER}/${SHARE} \
            ${MOUNT_POINT} || exit 1

    echo "Mounted."
fi

exit 0

