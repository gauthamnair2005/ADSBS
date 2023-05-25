#!/bin/bash
set -e
# Pass trap handlers to functions
set -E

# VT100 colors
declare -r  RED=$'\e[31m'
declare -r  GREEN=$'\e[32m'
declare -r  YELLOW=$'\e[33m'

# shellcheck disable=SC2034
declare -r  BLUE=$'\e[34m'
declare -r  OFF=$'\e[0m'
declare -r  BOLD=$'\e[1m'
declare -r  tab_=$'\t'
declare -r  nl_=$'\n'

# shellcheck disable=SC2034
declare -r   DD_BORDER="${BOLD}==============================================================================${OFF}"
# shellcheck disable=SC2034
declare -r   SD_BORDER="${BOLD}------------------------------------------------------------------------------${OFF}"
# shellcheck disable=SC2034
declare -r STAR_BORDER="${BOLD}******************************************************************************${OFF}"

# bold yellow > <  pair
declare -r R_arrow=$'\e[1;33m>\e[0m'
declare -r L_arrow=$'\e[1;33m<\e[0m'


#>>>>>>>>>>>>>>>ERROR TRAPPING >>>>>>>>>>>>>>>>>>>>
#-----------------------#
simple_error() {        # Basic error trap.... JUST DIE
#-----------------------#
  LASTLINE="$1"
  LASTERR="$2"
  LASTSOURCE="$4"
  error_message "${GREEN} Error $LASTERR at $LASTSOURCE line ${LASTLINE}!"
}

see_ya() {
  printf '\n%b%badsbs%b exit%b\n' "$L_arrow" "$BOLD" "$R_arrow" "$OFF"
}
##### Simple error TRAPS
# ctrl-c   SIGINT
# ctrl-y
# ctrl-z   SIGTSTP
# SIGHUP   1 HANGUP
# SIGINT   2 INTRERRUPT FROM KEYBOARD Ctrl-C
# SIGQUIT  3
# SIGKILL  9 KILL
# SIGTERM 15 TERMINATION
# SIGSTOP 17,18,23 STOP THE PROCESS
#####
set -e
trap see_ya 0
trap 'simple_error "${LINENO}" "$?" "${FUNCNAME}" "${BASH_SOURCE}"' ERR
trap 'echo -e "\n\n${RED}INTERRUPT${OFF} trapped\n" &&  exit 2' \
      HUP INT QUIT TERM # STOP stops tterminal output and does not seem to
                        # execute the handler
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

simple_message() {
  # Prevents having to check $VERBOSITY everywhere
  if [ "$VERBOSITY" -ne 0 ] ; then
    # shellcheck disable=SC2059
    printf "$*"
  fi
}

warning_message() {
  simple_message "${YELLOW}\\nWARNING:${OFF} $*\\n\\n"
}

error_message() {
  # Prints an error message and exits with LASTERR or 1
  if [ -n "$LASTERR" ] ; then
    LASTERR=$(printf '%d' "$LASTERR")
  else
    LASTERR=1
  fi
  # If +e then disable text output
  if [[ "$-" =~ e ]]; then
    printf '\n\n%bERROR:%b %s\n' "$RED" "$OFF" "$*" >&2
  fi
  exit "$LASTERR"
}

load_file() {
  # source files in a consistent way with an optional message
  file="$1"
  shift
  msg="Loading file ${file}..."
  [ -z "$*" ] || msg="$*..."
  simple_message "$msg"

  # shellcheck disable=SC1090
  source "$file" 2>/dev/null || error_message "$file did not load"
  simple_message "OK\\n"
}

version="
${BOLD}  \"adsbs\"${OFF} builder tool (development)
  $(cat git-version)

  Copyright (C) 2023, the adsbs team:
    Jeremy Huntwork
    George Boudreau
    Manuel Canales Esparcia
    Thomas Pegg
    Matthew Burgess
    Pierre Labastie

  Unless specified, all the files in this directory and its sub-directories
  are subjected to the ${BOLD}MIT license${OFF}. See the ${BOLD}LICENSE${OFF} file.
"

usage="${nl_}${tab_}${BOLD}${RED}This script cannot be called directly${OFF}
${tab_}Type ${BOLD}make${OFF} to run the tool, or
${tab_}Type ${BOLD}./adsbs -v${OFF} to display version information."

case $1 in
  -v ) echo "$version" && exit ;;
  run ) : ;;
  * ) echo "$usage" && exit 1 ;;
esac

# If the user has not saved his configuration file, let's ask
# if he or she really wants to run this stuff
time_current=$(stat -c '%Y' configuration 2>/dev/null || date +%s)
time_old=$(stat -c '%Y' .configuration.old 2>/dev/null || printf '%s' "$time_current")
if [ "$(printf '%d' "$time_old")" -ge "$(printf '%d' "$time_current")" ] ; then
  printf 'Do you want to run adsbs? yes/no (yes): '
  read -r ANSWER
  case ${ANSWER:0:1} in
    n|N) printf "\nExiting gracefully.\n"; exit ;;
  esac
fi

# Change this to 0 to suppress almost all messages
VERBOSITY=1

load_file configuration "Loading config params from <configuration>"

# These are boolean vars generated from Config.in.
# ISSUE: If a boolean parameter is not set to y(es) there
# is no variable defined by the menu app. This can
# cause a headache if you are not aware.
#  The following variables MUST exist. If they don't, the
#  default value is n(o).
RUNMAKE=${RUNMAKE:-n}
GETPKG=${GETPKG:-n}
COMPARE=${COMPARE:-n}
RUN_ICA=${RUN_ICA:-n}
PKGMNGT=${PKGMNGT:-n}
WRAP_INSTALL=${WRAP_INSTALL:-n}
BOMB_TEST=${BOMB_TEST:-n}
STRIP=${STRIP:=n}
REPORT=${REPORT:=n}
VIMLANG=${VIMLANG:-n}
DEL_LA_FILES=${DEL_LA_FILES:-n}
FULL_LOCALE=${FULL_LOCALE:-n}
GRSECURITY_HOST=${GRSECURITY_HOST:-n}
CUSTOM_TOOLS=${CUSTOM_TOOLS:-n}
REBUILD_MAKEFILE=${REBUILD_MAKEFILE:-n}
INSTALL_LOG=${INSTALL_LOG:-n}
CLEAN=${CLEAN:=n}
SET_SSP=${SET_SSP:=n}
SET_ASLR=${SET_ASLR:=n}
SET_PAX=${SET_PAX:=n}
SET_HARDENED_TMP=${SET_HARDENED_TMP:=n}
SET_WARNINGS=${SET_WARNINGS:=n}
SET_MISC=${SET_MISC:=n}
SET_BLOWFISH=${SET_BLOWFISH:=n}
UNICODE=${UNICODE:=n}
LOCAL=${LOCAL:=n}
REALSBU=${REALSBU:=n}

if [[ "${NO_PROGRESS_BAR}" = "y" ]] ; then
# shellcheck disable=SC2034
  NO_PROGRESS="#"
fi


# Sanity check on the location of $BUILDDIR / $adsbsDIR
CWD="$(cd "$(dirname "$0")" && pwd)"
if [[ $adsbsDIR == "$CWD" ]]; then
  echo " The adsbs source directory conflicts with the adsbs build directory."
  echo " Please move the source directory or change the build directory."
  exit 2
fi

# Book sources envars
BRANCH_ID=${BRANCH_ID:=development}

case $BRANCH_ID in
  development )
    case $PROGNAME in
      cds* ) TREE="" ;;
          * ) TREE=trunk/BOOK ;;
    esac
    dsVRS=development
    ;;
  *EDIT* )  echo " You forgot to set the branch or stable book version."
            echo " Please rerun make and fix the configuration."
            exit 2 ;;
  branch-* )
    case $PROGNAME in
      ds )
        dsVRS=${BRANCH_ID}
        TREE=branches/${BRANCH_ID#branch-}
        if [ ${BRANCH_ID:7:1} = 6 ]; then
            TREE=${TREE}/BOOK
        fi
        ;;
      cds* )
        dsVRS=${BRANCH_ID}
        TREE=${BRANCH_ID#branch-}
        ;;
    esac
    ;;
  * )
    case $PROGNAME in
      ds )
        dsVRS=${BRANCH_ID}
        TREE=tags/${BRANCH_ID}
        if (( ${BRANCH_ID:0:1} < 7 )) ; then
            TREE=${TREE}/BOOK
        fi
        ;;
      hds )
        dsVRS=${BRANCH_ID}
        TREE=tags/${BRANCH_ID}/BOOK
        ;;
      cds* )
        dsVRS=${BRANCH_ID}
        TREE=cds-${BRANCH_ID}
        ;;
      * )
    esac
    ;;
esac

# Set the document location...
BOOK=${BOOK:=$adsbsDIR/$PROGNAME-$dsVRS}


#--- Envars not sourced from configuration
# shellcheck disable=SC2034
case $PROGNAME in
  cds ) declare -r GIT="git://git.cds.org/cross-ds" ;;
  cds2 ) declare -r GIT="git://git.cds.org/cds-sysroot" ;;
  cds3 ) declare -r GIT="git://git.cds.org/cds-embedded" ;;
  *) declare -r SVN="svn://svn.linuxfromscratch.org" ;;
esac

declare -r LOG=000-masterscript.log
# Needed for fetching Bds book sources when building Cds
# shellcheck disable=SC2034
declare -r SVN_2="svn://svn.linuxfromscratch.org"

# Set true internal variables
COMMON_DIR="common"
PACKAGE_DIR=$(echo "$PROGNAME" | tr '[:lower:]' '[:upper:]')
MODULE=$PACKAGE_DIR/master.sh
PKGMNGTDIR="pkgmngt"
# The name packageManager.xml is hardcoded in *.xsl, so no variable.

for file in \
    "$COMMON_DIR/common-functions" \
    "$COMMON_DIR/libs/func_book_parser" \
    "$COMMON_DIR/libs/func_download_pkgs" \
    "$COMMON_DIR/libs/func_wrt_Makefile" \
    "$MODULE" ; do
  load_file "$file"
done

simple_message "${SD_BORDER}${nl_}"


#*******************************************************************#
LASTERR=2
for file in \
    "$COMMON_DIR/libs/func_check_version.sh" \
    "$COMMON_DIR/libs/func_validate_configs.sh" \
    "$COMMON_DIR/libs/func_custom_pkgs" ; do
  load_file "$file"
done
unset LASTERR

simple_message "${SD_BORDER}${nl_}"
simple_message "Checking tools required for adsbs${nl_}"
check_ads_tools
simple_message "${SD_BORDER}${nl_}"

# bds-tool envars
Bds_TOOL=${Bds_TOOL:-n}
if [[ "${Bds_TOOL}" = "y" ]] ; then
  simple_message 'Checking supplementary tools for installing Bds'
  check_bds_tools
  simple_message "${SD_BORDER}${nl_}"
  Bds_SVN=${Bds_SVN:-n}
  Bds_WORKING_COPY=${Bds_WORKING_COPY:-n}
  Bds_BRANCH=${Bds_BRANCH:-n}
  if [[ "${Bds_SVN}" = "y" ]]; then
    Bds_BRANCH_ID=development
    Bds_TREE=trunk/BOOK
  elif [[ "${Bds_WORKING_COPY}" = "y" ]]; then
    if [[ ! -d "$Bds_WC_LOCATION/postds" ]] ; then
      echo " Bds tools: This is not a working copy: $Bds_WC_LOCATION."
      echo " Please rerun make and fix the configuration."
      exit 2
    fi
    Bds_TREE=$(cd "$Bds_WC_LOCATION"; svn info | grep '^URL' | sed 's@.*Bds/@@')
    Bds_BRANCH_ID=$(echo "$Bds_TREE" | sed -e 's@trunk/BOOK@development@' \
                                             -e 's@branches/@branch-@' \
                                             -e 's@tags/@@' \
                                             -e 's@/BOOK@@')
  elif [[ "${Bds_BRANCH}" = "y" ]] ; then
    case $Bds_BRANCH_ID in
           *EDIT* )  echo " You forgot to set the Bds branch or stable book version."
                     echo " Please rerun make and fix the configuration."
                     exit 2 ;;
       branch-6.* )  Bds_TREE=branches/${Bds_BRANCH_ID#branch-}/BOOK ;;
         branch-* )  Bds_TREE=branches/${Bds_BRANCH_ID#branch-} ;;
  6.2* | 7.* | 8.*)  Bds_TREE=tags/${Bds_BRANCH_ID} ;;
                * )  Bds_TREE=tags/${Bds_BRANCH_ID}/BOOK ;;
    esac
  fi
  load_file "${COMMON_DIR}/libs/func_install_bds"
fi

###################################
###          MAIN               ###
###################################


validate_config
echo "${SD_BORDER}${nl_}"
echo -n "Are you happy with these settings? yes/no (no): "
read -r ANSWER
if [ "x$ANSWER" != "xyes" ] ; then
  echo "${nl_}Rerun make to fix the configuration options.${nl_}"
  exit
fi
echo "${nl_}${SD_BORDER}${nl_}"

# Load additional modules or configuration files based on global settings
# compare module
if [[ "$COMPARE" = "y" ]]; then
  load_file "${COMMON_DIR}/libs/func_compare.sh" 'Loading compare module'
fi
#
# optimize module
if [[ "$OPTIMIZE" != "0" ]]; then
  load_file optimize/optimize_functions 'Loading optimization module'
  #
  # optimize configurations
  load_file optimize/opt_config 'Loading optimization config'
  # The number of parallel jobs is taken from configuration now
  # shellcheck disable=SC2034
  MAKEFLAGS="-j${N_PARALLEL}"
  # Validate optimize settings, if required
  validate_opt_settings
fi
#

if [[ "$REBUILD_MAKEFILE" = "n" ]] ; then

# If requested, clean the build directory
  clean_builddir

  if [[ ! -d $adsbsDIR ]]; then
    sudo mkdir -p "$adsbsDIR"
    sudo chown "$USER":"$USER" "$adsbsDIR"
  fi

# Create $BUILDDIR/sources even though it could be created by get_sources()
  if [[ ! -d $BUILDDIR/sources ]]; then
    sudo mkdir -p "$BUILDDIR/sources"
    sudo chmod a+wt "$BUILDDIR/sources"
  fi

# Create the log directory
  if [[ ! -d $LOGDIR ]]; then
    mkdir "$LOGDIR"
  fi
  true >"$LOGDIR/$LOG"

# Copy common helper files
  cp "$COMMON_DIR"/{makefile-functions,progress_bar.sh} "$adsbsDIR/"

# Copy needed stylesheets
  cp "$COMMON_DIR"/{packages.xsl,chroot.xsl,kernfs.xsl} "$adsbsDIR/"

# Fix the XSL book parser
  case $PROGNAME in
    cds* ) sed 's,FAKEDIR,'"${BOOK}/BOOK"',' "${PACKAGE_DIR}/${XSL}" > "${adsbsDIR}/${XSL}" ;;
    ds | hds ) sed 's,FAKEDIR,'"$BOOK"',' "${PACKAGE_DIR}/${XSL}" > "${adsbsDIR}/${XSL}" ;;
    * ) ;;
  esac
  export XSL=$adsbsDIR/${XSL}

# Copy packageManager.xml, if needed
  [[ "$PKGMNGT" = "y" ]] && [[ "$PROGNAME" = "ds" ]] && {
    cp "$PKGMNGTDIR/packageManager.xml" "$adsbsDIR/"
    cp "$PKGMNGTDIR/packInstall.sh" "$adsbsDIR/"
    }

# Copy urls.xsl, if needed
  [[ "$GETPKG" = "y" ]] && cp "$COMMON_DIR/urls.xsl" "$adsbsDIR/"

# Always create the test-log directory to allow user to "uncomment" test
# instructions
  install -d -m 1777 "$TESTLOGDIR"

# Create the installed-files directory, if needed
  [[ "$INSTALL_LOG" = "y" ]] && [[ ! -d $FILELOGDIR ]] && install -d -m 1777 "$FILELOGDIR"

# Prepare report creation, if needed
  if [[ "$REPORT" = "y" ]]; then
    cp $COMMON_DIR/create-sbu_du-report.sh  "$adsbsDIR/"
    # After making sure that all looks sane, dump the settings to a file
    # This file will be used to create the REPORT header
    validate_config >"$adsbsDIR/adsbs.config"
  fi

# Copy optimize files, if needed
  [[ "$OPTIMIZE" != "0" ]] && cp optimize/opt_override "$adsbsDIR/"

# Copy compare files, if needed
  if [[ "$COMPARE" = "y" ]]; then
    mkdir -p "$adsbsDIR/extras"
    cp extras/* "$adsbsDIR/extras"
  fi

# Copy custom tools config files, if requested
  if [[ "${CUSTOM_TOOLS}" = "y" ]]; then
    echo "Copying custom tool scripts to $adsbsDIR"
    mkdir -p "$adsbsDIR/custom-commands"
    cp -f custom/config/* "$adsbsDIR/custom-commands"
  fi

# Download or updates the book source
# Note that all customization to $adsbsDIR have to be done before this.
# But the ds book is needed for Bds tools.
  get_book
  extract_commands
  echo "${SD_BORDER}${nl_}"
  cd "$CWD" # the functions above change directory

# Install bds-tool, if requested.
  if [[ "${Bds_TOOL}" = "y" ]] ; then
    echo Installing Bds book and tools
    install_bds_tools 2>&1 | tee -a "$LOGDIR/$LOG"
    [[ ${PIPESTATUS[0]} != 0 ]] && exit 1
  fi

fi

# When regenerating the Makefile, we need to know also the
# canonical book version
# shellcheck disable=SC2034
if [[ "$REBUILD_MAKEFILE" = "y" ]] ; then
  case $PROGNAME in
    cds* )
      VERSION=$(xmllint --noent "$BOOK/prologue/$ARCH/bookinfo.xml" 2>/dev/null | grep subtitle | sed -e 's/^.*ion //'  -e 's/<\/.*//') ;;
    ds)
      if [[ "$INITSYS" = "sysv" ]] ; then
        VERSION=$(grep 'ENTITY version ' "$BOOK/general.ent" | cut -d\" -f2)
      else
        VERSION=$(grep 'ENTITY versiond' "$BOOK/general.ent" | cut -d\" -f2)
      fi
      ;;
    *)
      VERSION=$(xmllint --noent "$BOOK/prologue/bookinfo.xml" 2>/dev/null | grep subtitle | sed -e 's/^.*ion //'  -e 's/<\/.*//') ;;
  esac
fi

build_Makefile

echo "${SD_BORDER}${nl_}"

# Check for build prerequisites.
  echo
  cd "$CWD"
  check_prerequisites
  echo "${SD_BORDER}${nl_}"
# All is well, run the build (if requested)
run_make
