#!/bin/bash
set -e

: << inline_doc
Installs a set-up to build EDS packages.
You can set these variables:
TRACKING_DIR  : where the installed package file is kept.
                (default /var/lib/adsbs/EDS)
INITSYS       : which books do you want? 'sysv' or 'systemd' (default sysv)
EDS_ROOT     : where the installed tools will be installed, relative to $HOME.
                Must start with a '/' (default /eds_root)
EDS_BRANCH_ID: development, branch-xxx, xxx (where xxx is a valid tag)
                (default development)
DS_BRANCH_ID : development, branch-xxx, xxx (where xxx is a valid tag)
                (default development)
Examples:
1 - If you plan to use the tools to build EDS on top of DS, but you did not
use adsbs, or forgot to include the adsbs-eds tools:
(as root) mkdir -p /var/lib/adsbs/EDS && chown -R <user> /var/lib/adsbs
(as user) INITSYS=<your system> ./install-eds-tools.sh
2 - To install with only user privileges (default to sysv):
TRACKING_DIR=$HOME/eds_root/trackdir ./install-eds-tools.sh

This script can also be called automatically after running make in this
directory. The parameters will then be taken from the configuration file.
inline_doc


# VT100 colors
declare -r  BLACK=$'\e[1;30m'
declare -r  DK_GRAY=$'\e[0;30m'

declare -r  RED=$'\e[31m'
declare -r  GREEN=$'\e[32m'
declare -r  YELLOW=$'\e[33m'
declare -r  BLUE=$'\e[34m'
declare -r  MAGENTA=$'\e[35m'
declare -r  CYAN=$'\e[36m'
declare -r  WHITE=$'\e[37m'

declare -r  OFF=$'\e[0m'
declare -r  BOLD=$'\e[1m'
declare -r  REVERSE=$'\e[7m'
declare -r  HIDDEN=$'\e[8m'

declare -r  tab_=$'\t'
declare -r  nl_=$'\n'

declare -r   DD_BORDER="${BOLD}==============================================================================${OFF}"
declare -r   SD_BORDER="${BOLD}------------------------------------------------------------------------------${OFF}"
declare -r STAR_BORDER="${BOLD}******************************************************************************${OFF}"
declare -r dotSTR=".................." # Format display of parameters and versions

# bold yellow > <  pair
declare -r R_arrow=$'\e[1;33m>\e[0m'
declare -r L_arrow=$'\e[1;33m<\e[0m'
VERBOSITY=1

# Take parameters from "configuration" if $1="auto"
if [ "$1" = auto ]; then
  [[ $VERBOSITY > 0 ]] && echo -n "Loading configuration ... "
  source configuration
  [[ $? > 0 ]] && echo -e "\nconfiguration could not be loaded" && exit 2
  [[ $VERBOSITY > 0 ]] && echo "OK"
fi

if [ "$BOOK_EDS" = y ]; then
## Read variables and sanity checks
  [[ "$relSVN" = y ]] && EDS_BRANCH_ID=development
  [[ "$BRANCH" = y ]] && EDS_BRANCH_ID=$BRANCH_ID
  [[ "$WORKING_COPY" = y ]] && EDS_BOOK=$BOOK
  [[ "$BRANCH_ID" = "**EDIT ME**" ]] &&
    echo You have not set the EDS book version or branch && exit 1
  [[ "$BOOK" = "**EDIT ME**" ]] &&
    echo You have not set the EDS working copy location && exit 1
  [[ "$DS_relSVN" = y ]] && DS_BRANCH_ID=development
  [[ "$DS_BRANCH" = y ]] && DS_BRANCH_ID=$EDS_DS_BRANCH_ID
  [[ "$DS_WORKING_COPY" = y ]] && DS_BOOK=$EDS_DS_BOOK
  [[ "$DS_BRANCH_ID" = "**EDIT ME**" ]] &&
    echo You have not set the DS book version or branch && exit 1
  [[ "$DS_BOOK" = "**EDIT ME**" ]] &&
    echo You have not set the DS working copy location && exit 1
fi

COMMON_DIR="common"
# eds-tool envars
EDS_TOOL='y'
BUILDDIR=$(cd ~;pwd)
EDS_ROOT="${EDS_ROOT:=/eds_root}"
TRACKING_DIR="${TRACKING_DIR:=/var/lib/adsbs/EDS}"
INITSYS="${INITSYS:=sysv}"
EDS_BRANCH_ID=${EDS_BRANCH_ID:=development}
DS_BRANCH_ID=${DS_BRANCH_ID:=development}
EDS_XML=${EDS_XML:=eds-xml}
DS_XML=${DS_XML:=ds-xml}

# Validate the configuration:
PARAMS="EDS_ROOT TRACKING_DIR INITSYS EDS_XML DS_XML"
if [ "$WORKING_COPY" = y ]; then
  PARAMS="$PARAMS WORKING_COPY EDS_BOOK"
else
  PARAMS="$PARAMS EDS_BRANCH_ID"
fi
if [ "$DS_WORKING_COPY" = y ]; then
  PARAMS="$PARAMS DS_WORKING_COPY DS_BOOK"
else
  PARAMS="$PARAMS DS_BRANCH_ID"
fi
# Format for displaying parameters:
declare -r PARAM_VALS='${config_param}${dotSTR:${#config_param}} ${L_arrow}${BOLD}${!config_param}${OFF}${R_arrow}'

for config_param in $PARAMS; do
  echo -e "`eval echo $PARAM_VALS`"
done

echo "${SD_BORDER}${nl_}"
echo -n "Are you happy with these settings? yes/no (no): "
read ANSWER
if [ x$ANSWER != "xyes" ] ; then
  echo "${nl_}Rerun make and fix your settings.${nl_}"
  exit
fi
[[ $VERBOSITY > 0 ]] && echo "${SD_BORDER}${nl_}"

#*******************************************************************#
[[ $VERBOSITY > 0 ]] && echo -n "Loading function <func_check_version.sh>..."
source $COMMON_DIR/libs/func_check_version.sh
[[ $? > 0 ]] && echo " function module did not load.." && exit 2
[[ $VERBOSITY > 0 ]] && echo "OK"

[[ $VERBOSITY > 0 ]] && echo "${SD_BORDER}${nl_}"

case $EDS_BRANCH_ID in
     development )  EDS_TREE=trunk/BOOK ;;
      branch-6.* )  EDS_TREE=branches/${EDS_BRANCH_ID#branch-}/BOOK ;;
        branch-* )  EDS_TREE=branches/${EDS_BRANCH_ID#branch-} ;;
6.2* | 7.* | 8.* )  EDS_TREE=tags/${EDS_BRANCH_ID} ;;
               * )  EDS_TREE=tags/${EDS_BRANCH_ID}/BOOK ;;
esac
case $DS_BRANCH_ID in
  development )  DS_TREE=trunk/BOOK ;;
   branch-6.* )  DS_TREE=branches/${DS_BRANCH_ID#branch-}/BOOK ;;
     branch-* )  DS_TREE=branches/${DS_BRANCH_ID#branch-} ;;
          6.* )  DS_TREE=tags/${DS_BRANCH_ID}/BOOK ;;
            * )  DS_TREE=tags/${DS_BRANCH_ID} ;;
esac

# Check for build prerequisites.
echo
  check_ads_tools
  check_eds_tools
echo "${SD_BORDER}${nl_}"

# Install the files
[[ $VERBOSITY > 0 ]] && echo -n Populating the ${BUILDDIR}${EDS_ROOT} directory
[[ ! -d ${BUILDDIR}${EDS_ROOT} ]] && mkdir -pv ${BUILDDIR}${EDS_ROOT}
rm -rf ${BUILDDIR}${EDS_ROOT}/*
cp -r EDS/* ${BUILDDIR}${EDS_ROOT}
cp -r menu ${BUILDDIR}${EDS_ROOT}
cp $COMMON_DIR/progress_bar.sh ${BUILDDIR}${EDS_ROOT}
cp README.EDS ${BUILDDIR}${EDS_ROOT}
[[ $VERBOSITY > 0 ]] && echo "... OK"

# Clean-up
[[ $VERBOSITY > 0 ]] && echo Cleaning the ${BUILDDIR}${EDS_ROOT} directory
# We do not want to keep an old version of the book:
rm -rf ${BUILDDIR}${EDS_ROOT}/$EDS_XML
rm -rf ${BUILDDIR}${EDS_ROOT}/$DS_XML

# Set some harcoded envars to their proper values
sed -i s@tracking-dir@$TRACKING_DIR@ \
    ${BUILDDIR}${EDS_ROOT}/{Makefile,gen-makefile.sh}

# Ensures the tracking directory exists.
# Throws an error if it does not exist and the user does not
# have write permission to create it.
# If it exists, does nothing.
mkdir -p $TRACKING_DIR
[[ $VERBOSITY > 0 ]] && echo "... OK"

[[ $VERBOSITY > 0 ]] &&

[[ -z "$EDS_BOOK" ]] ||
[[ $EDS_BOOK = $BUILDDIR$EDS_ROOT/$EDS_XML ]] || {
echo "Retrieving EDS working copy (may take some time)" &&
cp -a $EDS_BOOK $BUILDDIR$EDS_ROOT/$EDS_XML
}

[[ -z "$DS_BOOK" ]] ||
[[ $DS_BOOK = $BUILDDIR$EDS_ROOT/$DS_XML ]] || {
echo "Retrieving the DS working copy (may take some time)" &&
cp -a $DS_BOOK $BUILDDIR$EDS_ROOT/$DS_XML
}

make -j1 -C $BUILDDIR$EDS_ROOT \
     TRACKING_DIR=$TRACKING_DIR \
     REV=$INITSYS            \
     DS_XML=$BUILDDIR$EDS_ROOT/$DS_XML      \
     DS-SVN=svn://svn.linuxfromscratch.org/DS/$DS_TREE \
     EDS_XML=$BUILDDIR$EDS_ROOT/$EDS_XML      \
     SVN=svn://svn.linuxfromscratch.org/EDS/$EDS_TREE \
     $BUILDDIR$EDS_ROOT/packages.xml
[[ $VERBOSITY > 0 ]] && echo "... OK"

