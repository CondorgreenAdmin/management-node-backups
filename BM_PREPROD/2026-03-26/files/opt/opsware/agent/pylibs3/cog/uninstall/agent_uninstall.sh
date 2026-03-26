#!/bin/sh

# ------------
# Trap signals
# ------------
trap ignore 1 2 3 4 15
ignore()
{
  echo ''
}


ERRMSGNOTROOT="ERROR:  You will need root privileges to run this script.  Agent uninstall aborted."
ERRMSGNOPYTHON="ERROR:  Python interpreter not found in Opsware bin directory.  Agent uninstall aborted."
ERRMSGRUNFROMBIN="ERROR:  You must run the uninstaller from the Opsware bin directory."

PATH=/usr/bin:/bin:$PATH


# ---------
# Check uid
# ---------
USERID=`id | cut -f2 -d= | cut -f1 -d\(`
if [ x"0" != x"${USERID}" ]; then
  echo ${ERRMSGNOTROOT}
  exit 1
fi


BINNAME=`basename $0`
BINDIR=`dirname $0`
if [ x"${BINDIR}" = x"." ]; then
  BINDIR=`pwd`
fi


# -------------------------------------------
# Check if running from Opsware bin directory
# -------------------------------------------
PBASEDIR=`basename ${BINDIR}`
if [ ! x"bin" = x"${PBASEDIR}" ]; then
  echo ${ERRMSGRUNFROMBIN}
  exit 1
fi


INSTDIR=`dirname ${BINDIR}`
PYTHONBIN=${BINDIR}/python3
PATH=${BINDIR}:/usr/bin:/bin:$PATH

# ---------------------------------------------
# Check for Python interpreter in bin directory
# ---------------------------------------------
if [ ! -f ${PYTHONBIN} ]; then
  echo ${ERRMSGNOPYTHON}
  exit 1
fi


# Make sure we're not in a directory that we're going to delete
cd /tmp


# Call python script to stop bots, remove /var/opt/opsware, deactivate, remove rpm
${PYTHONBIN} -E -m cog.uninstall.agent_uninstall "$@"


# If exit code from python script is ok (0) or cannot decommision (100),
# attempt to delete install directory
if [ "$?" = "0" -o "$?" = "100" ]; then
  if [ -d ${INSTDIR} ]; then
    rm -rf ${INSTDIR}
    if [ "$?" != "0" ]; then
      exit 1
    fi
  fi
fi

exit 0
