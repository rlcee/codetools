#! /bin/bash
#
# $1 = the release directory (= path/Offline)
#   if not supplied, will try $PWD
#
#

usage() {
echo "
Usage: cleanupRelease [OPTION]... [DIRECTORY]

Remove all temporary files in a release directory (*.so, tmp/* etc.)
The directory argument must end with 'Offline'

  -n           do not delete, just list files to delete
  -h           print help
"
exit 0
}

RDIR="$PWD"
COMMAND="rm -rf "

while getopts nh OPT; do
    case $OPT in
        n)  COMMAND="ls -d1 " ;;
        h)  usage ;;
     esac
done

ARG1=${@:$OPTIND:1}
[ "$ARG1" != "" ] && RDIR="$ARG1"

# check if RDIR is a release directory
RDIR=`readlink -f $RDIR`

if [ ! -d $RDIR ]; then
  echo "$RDIR is not a directory - exiting"
  exit 1
fi

if [ "`basename $RDIR`" != "Offline" ]; then
  echo "$RDIR is not a release directory ending in ""Offline"" - exiting"
  exit 1
fi

# do the deletes (or listing..)

$COMMAND $RDIR/tmp
$COMMAND $RDIR/.git
$COMMAND $RDIR/.sconsign.dblite

find $RDIR -name \*.os -exec $COMMAND {} +
find $RDIR -name \*.o  -exec $COMMAND {} +
find $RDIR -name .svn  -exec $COMMAND {} +

exit 0

