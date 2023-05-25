#!/bin/bash
#
#
set -e

declare TOPDIR='..'
declare ATOPDIR=`cd $TOPDIR; pwd`
declare MKFILE=Makefile
declare PREV_PACKAGE=""
declare BUILD_SCRIPTS=${TOPDIR}/scripts
declare TRACKING_FILE=tracking-dir/instpkg.xml
declare XSLDIR=${TOPDIR}/xsl
declare PACK_FILE=${TOPDIR}/packages.xml
declare BUMP=${XSLDIR}/bump.xsl

HEADER="# This file is automatically generated by gen-makefile.sh
# YOU MAY NEED TO EDIT THIS FILE MANUALLY
#
# Generated on `date \"+%F %X %Z\"`"


#----------------------------------#
__wrt_target() {                   # Create target and initialize log file
#----------------------------------#
  local i=$1
  local PREV=$2
(
cat << EOF

$i:  $PREV
	@\$(call echo_message, Building)
	@/bin/bash progress_bar.sh \$@ \$\$PPID &
EOF
) >> $MKFILE.tmp
}



#----------------------------------#
__write_build_cmd() {              #
#----------------------------------#
(
cat << EOF
	@source ${TOPDIR}/envars.conf && ${BUILD_SCRIPTS}/\$@ >logs/\$@ 2>&1
EOF
) >> $MKFILE.tmp
}

#----------------------------------#
__wrt_touch() {                    #
#----------------------------------#
  local pkg_name=$1

(
cat << EOF
	@xsltproc --stringparam packages ${PACK_FILE} \\
	--stringparam package ${pkg_name#*-?-} \\
	-o track.tmp \\
	${BUMP} \$(TRACKING_FILE) && \\
	sed -i 's@PACKDESC@${ATOPDIR}/packdesc.dtd@' track.tmp && \\
	xmllint --format --postvalid track.tmp > \$(TRACKING_FILE) && \\
        rm track.tmp && \\
	touch  \$@ && \\
	sleep .25 && \\
	echo -e "\n\n "\$(BOLD)Target \$(BLUE)\$@ \$(BOLD)OK && \\
	echo --------------------------------------------------------------------------------\$(WHITE)
EOF
) >> $MKFILE.tmp
}


#----------------------------#
__write_entry() {            #
#----------------------------#
  local script_name=$1

  echo -n "${tab_}${tab_} entry for <$script_name>"

  #--------------------------------------------------------------------#
  #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
  #--------------------------------------------------------------------#
  #
  # Drop in the name of the target on a new line, and the previous target
  # as a dependency. Also call the echo_message function.
  __wrt_target "${script_name}" "$PREV_PACKAGE"
  __write_build_cmd

  # Include a touch of the target name so make can check
  # if it's already been made.
  __wrt_touch "${script_name}"
  #
  #--------------------------------------------------------------------#
  #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
  #--------------------------------------------------------------------#
  echo " .. OK"
}

#----------------------------#
generate_Makefile () {       #
#----------------------------#


  echo "${tab_}Creating Makefile... ${BOLD}START${OFF}"

  # Start with a clean files
  >$MKFILE
  >$MKFILE.tmp


  for package_script in ${BUILD_SCRIPTS}/* ; do
    this_script=`basename $package_script`
    pkg_list="$pkg_list ${this_script}"
    __write_entry "${this_script}"
    PREV_PACKAGE=${this_script}
  done

(
    cat << EOF
$HEADER

TRACKING_FILE= $TRACKING_FILE

BOLD= "[0;1m"
RED= "[1;31m"
GREEN= "[0;32m"
ORANGE= "[0;33m"
BLUE= "[1;34m"
WHITE= "[00m"

define echo_message
  @echo \$(BOLD)
  @echo --------------------------------------------------------------------------------
  @echo \$(BOLD)\$(1) target \$(BLUE)\$@\$(BOLD)
  @echo \$(WHITE)
endef


define end_message
  @echo \$(BOLD)
  @echo --------------------------------------------------------------------------------
  @echo \$(BOLD) Build complete for the package \$(BLUE)\$(PACKAGE)\$(BOLD) and its dependencies
  @echo \$(WHITE)
endef

all : $pkg_list
	@\$(call end_message )
EOF
) > $MKFILE

  cat $MKFILE.tmp >> $MKFILE
  echo "${tab_}Creating Makefile... ${BOLD}DONE${OFF}"

  rm $MKFILE.tmp

}

if [[ ! -d ${BUILD_SCRIPTS} ]] ; then
  echo -e "\n\tThe '${BUILD_SCRIPTS}' directory has not been found.\n"
  exit 1
fi

# Let us make a clean base, but first ensure that we are
# not emptying a useful directory.
MYDIR=$(pwd)
MYDIR=$(basename $MYDIR)
if [ "${MYDIR#work}" = "${MYDIR}" ] ; then
  echo -e \\n\\tDirectory ${BOLD}$MYDIR${OFF} does not begin with \"work\"\\n
  exit 1
fi

rm -rf *

generate_Makefile

cp ${TOPDIR}/progress_bar.sh .

mkdir -p logs
