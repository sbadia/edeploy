#!/bin/bash

# Script used by Jenkins jobs to build roles and archive them if the target directory exists

if [ $# -lt 3 ]; then
    echo "$0 <src dir> <build dir> <archive dir> [<make params>...]" 1>&2
    exit 1
fi

set -e

SRC="$1"
shift
DIR="$1"
shift
ARCH="$1"
shift

cleanup() {
    if [ -d "$DIR" ]; then
	sudo rm -rf "$DIR"/install/
    fi
}

#trap cleanup 0

if [ -z "$ROLES" ]; then
    ROLES="base pxe health-check"
    # Build the deploy role under Debian and Ubuntu only
    if [ -r /etc/debian_version ]; then
	ROLES="$ROLES deploy"
	if ! type -p ansible; then
	    if ! type -p pip; then
		apt-get install python-pip
	    fi
	    pip install ansible
	fi
    fi
fi

set -x

cd $SRC
#cleanup
sudo mkdir -p "$DIR"/install
RC=0
BROKEN=
for role in $ROLES; do
    if sudo make TOP="$DIR" ARCHIVE="$ARCH" "$@" $role; then
	if [ -d "$ARCH" ]; then
	    VERS=$(sudo make TOP="$DIR" "$@" version)
	    mkdir -p "$ARCH"/$VERS/
	    sudo rsync -a "$DIR"/install/$VERS/*.* "$ARCH"/$VERS/
	    git rev-parse HEAD > "$ARCH"/$VERS/$role.rev
	fi
    else
	BROKEN="$BROKEN $role"
	RC=1
    fi
done

set +x

if [ -n "$BROKEN" ]; then
    echo "BROKEN ROLES:$BROKEN"
fi

exit $RC
