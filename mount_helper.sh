#!/bin/bash

# INIT
ROOT_MEDIA="/media"


test_setup() {
    if [ ! -f "/sbin/mount.cifs" ]; then
        echo "Could not find mount.cifs, consider: sudo apt install cifs-utils"
        exit 1
    fi
}

# Test tooling
test_setup


#######################################
usage() {
    echo "Usage: $0 [-c | -d] [-s <server host>] [-r <share name>] [-u <remote username>] [-p <remote password>] [-m <mount point>] [-w ro | rw]" 1>&2;
    exit 1;
}

while getopts "vcds:r:u:p:m:w:" o; do
    case "${o}" in
        v)  # Verbose
            vflag=1
            VERBOSE=1
            ;;
        c)  # CIFS choosen
            cflag=1
            TYPE_FS="cifs"
            ;;
        d)  # DAV choosen
            dflag=1
            TYPE_FS="dav"
            ;;
        s)  # Server (cifs)
            sflag=1
            SERVER=${OPTARG}
            ;;
        r)  # Share (or resource)
            rflag=1
            SHARE=${OPTARG}
            ;;
        u)  # User (remote)
            uflag=1
            REMOTE_USER=${OPTARG}
            ;;
        p)  # Password (remote)
            pflag=1
            REMOTE_PASS=${OPTARG}
            ;;
        m)  # Mount point
            mflag=1
            MOUNT_POINT=${OPTARG}
            ;;
        w)  # Read write mount
            wflag=1
            RORW=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
#shift $(($OPTIND - 1))

# Check: CIFS and DAV together is an error.
if [ ! -z "$cflag" ] && [ ! -z "$dflag" ]; then
    echo "Error: both CIFS and DAV selected"
    echo
    usage
fi

# Check: when the w flag is set, check if only ro or rw
if [ ! -z "$wflag" ]; then
    if [ $RORW != "ro" ] && [ $RORW != "rw" ]; then
        echo "Error: -w flag only accepts 'ro' or 'rw' values"
        echo
        usage
    fi
fi


#######################################

# usage

if [ ! -z $VERBOSE ]; then
    echo "# Input from parameters:"
    echo "TYPE of network mount:    $TYPE_FS"
    echo "Remote username:          $REMOTE_USER"
    echo "Remote password:          $REMOTE_PASS"
    echo "Server host:              $SERVER"
    echo "Share name:               $SHARE"
    echo "Read-only of Read-Write:  $RORW"
    echo "##"
    echo
fi


# TYPE_FS - When not set, ask
if [ -z "$TYPE_FS" ]; then
    echo "Samba or WebDAV"
    echo "1. Samba / CIFS"
    echo "2. WebDAV"
    echo -n "Choice: "
    read CHOICE

    case $CHOICE in
        1)
            TYPE_FS="cifs"
            ;;
        2)
            TYPE_FS="dav"
            ;;
        *)
            echo "Make a choice on the thing to be mounted."
            exit 1
            ;;
    esac
fi


if [ "$TYPE_FS" = "cifs" ]; then
    if [ -z "$SERVER" ]; then
        echo -n "Server: "
        read SERVER
    fi

    if [ -z "$SHARE" ]; then
        echo -n "Share: "
        read SHARE
    fi

    MOUNT_POINT="${ROOT_MEDIA}/${SERVER}/${SHARE}"
    echo -n "Accept generated mount point: "
    echo "${MOUNT_POINT}"

elif [ "$TYPE_FS" = "dav" ]; then
    echo -n "WebDAV URL: "
    read WEBDAV_URL

    CLEAN_WEBDAV_URL=$(echo ${WEBDAV_URL} | sed 's|://|_|g')
    CLEAN_WEBDAV_URL=$(echo ${CLEAN_WEBDAV_URL=} | sed 's|\.|-|g')
    CLEAN_WEBDAV_URL=$(echo ${CLEAN_WEBDAV_URL=} | sed 's|/|_|g')
    # echo ${CLEAN_WEBDAV_URL}

    MOUNT_POINT="${ROOT_MEDIA}/${CLEAN_WEBDAV_URL}"
    echo -n "Accept generated mount point: "
    echo "${MOUNT_POINT}"
fi


if [ -z $REMOTE_USER ]; then
    echo -n "User: "
    read REMOTE_USER
fi


# Generate the password file for this endpoint
GEN_PASSWD_FILE="$HOME/.${SERVER}.${SHARE}.${REMOTE_USER}.cifs"

if [ -f "${GEN_PASSWD_FILE}" ]; then
    echo "Found password file: ${GEN_PASSWD_FILE}"
    REMOTE_PASS=$(cat "${GEN_PASSWD_FILE}")

else
        if [ -z $REMOTE_PASS ]; then
            echo -n "Password: "
            stty -echo
            # printf "Password: "
            read REMOTE_PASS
            stty echo
            echo
        fi
fi

# Store password
export PASSWD="${REMOTE_PASS}"


echo -n "Accept mounting user. "
echo -n "=> "
id -a
MNT_UID=$(id -u)
MNT_GID=$(id -g)
echo


if [ -z $RORW ]; then
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
fi

sync

if [ $(id -u) != 0 ]; then
    echo "Upgrade with sudo..."
    # Priming the cache, when sudo is configured to be able to
    sudo id -a
    echo
fi

if [ ! -d "${MOUNT_POINT}" ]; then
    echo "Creating ${MOUNT_POINT}"
    sudo mkdir -p ${MOUNT_POINT}
    echo
fi


echo "Check if already mounted..."
if [ $(mount | grep -c ${MOUNT_POINT}) -ne 0 ]; then
    echo "Error: already mounted ${MOUNT_POINT}, halting process"
    exit 1
fi


#Mounting
if [ "$TYPE_FS" = "cifs" ]; then

    echo -n "Mounting //${SERVER}/${SHARE} "
    echo -n "as ${REMOTE_USER} "
    echo -n "to ${MOUNT_POINT} "
    echo -n "for uid=$(id -u)($(id -un)) "
    echo -n "gid=$(id -g)($(id -gn))"
    echo

#    sudo \
#        mount.cifs \
#            -o $RORW,username=${REMOTE_USER},password=${REMOTE_PASS},uid=${MNT_UID},gid=${MNT_GID} \
#            //${SERVER}/${SHARE} \
#            ${MOUNT_POINT} || exit 1

    # PASSWD contains CIFS password

    sudo \
        --preserve-env \
        mount.cifs \
            -v \
            -o $RORW,username=${REMOTE_USER},uid=${MNT_UID},gid=${MNT_GID} \
            //${SERVER}/${SHARE} \
            ${MOUNT_POINT} || exit 1

elif [ "$TYPE_FS" = "dav" ]; then

    echo -n "Mounting ${WEBDAV_URL} "
    echo -n "as ${REMOTE_USER} "
    echo -n "to ${MOUNT_POINT} "
    echo -n "for uid=$(id -u)($(id -un)) "
    echo -n "gid=$(id -g)($(id -gn))"
    echo

    echo "${REMOTE_PASS}" | \
    sudo \
        mount -t davfs \
            -o $RORW,username=${REMOTE_USER},uid=${MNT_UID},gid=${MNT_GID} \
            ${WEBDAV_URL} \
            ${MOUNT_POINT} || exit 1
fi

echo "Mounted."

