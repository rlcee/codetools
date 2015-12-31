#! /bin/bash

usage() {
echo "

    build <options>

    -b build code
    -i install as a product in $PRODUCTDIR/codetools/$VERSION
    -v VERSION
    -d PRODUCTDIR
    -h print this help

"
}

build() {
  echo "

  This product is only scripts, so does not ned building

"
  return 1
}

install() {

  local RC
  local DD=$PRODUCTDIR/$PRODUCT/$VERSION
  local DU=$DD/ups
  local DV=$PRODUCTDIR/$PRODUCT/${VERSION}.version
  echo "Will install in $DD"
  if  ! mkdir -p $DD  ; then
    echo "ERROR - failed to make release dir $DD"
    return 1
  fi
  mkdir -p $DV
  mkdir -p $DU
  mkdir -p $DD/bin

  # install UPS files
  cat $SOURCEDIR/prd/NULL \
     | sed 's/REPLACE_VERSION/'$VERSION'/'    \
     > $DV/NULL

  cat $SOURCEDIR/prd/codetools.table \
     | sed 's/REPLACE_VERSION/'$VERSION'/'    \
     > $DD/ups/codetools.table

  # install scripts
  cp $SOURCEDIR/bin/* $DD/bin
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "ERROR - failed to cp $DD/bin/val\*.sh $DD/bin"
    return 1
  fi

  return 0
}

# ********** main **********

PRODUCT=codetools
THISDIR=`dirname $(readlink -f $0)`
SOURCEDIR=`readlink -f $THISDIR/..`

DOBUILD=""
DOINSTALL=""
PRODUCTDIR="$PWD"
VERSION="v0"

while getopts bd:iv:h OPT; do
    case $OPT in
        b)
            export DOBUILD=true
            ;;
        d)
            export PRODUCTDIR=$OPTARG
            ;;
        i)
            export DOINSTALL=true
            ;;
        v)
            export VERSION=$OPTARG
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            echo unknown option, exiting
	    usage
            exit 1
            ;;
     esac
done

if [[ -z "$DOBUILD" && -z "$DOINSTALL" ]]; then
  echo "ERROR - no actions requested"
  usage
  exit 2
fi

if [ -n "$DOBUILD" ]; then
  if ! build ; then
    exit 3
  fi
fi

if [ -n "$DOINSTALL" ]; then
  if ! install ; then
    exit 4
  fi
fi

echo "Done"



