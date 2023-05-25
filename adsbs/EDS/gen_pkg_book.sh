#!/bin/bash
#
#
#  Read and parse the configuration parameters..
#
set -e

TOPDIR=$1
if test -z "$TOPDIR"; then
  TOPDIR=$(pwd)
fi
Bds_FULL=$2
if test -z "$Bds_FULL"; then
  Bds_FULL=${TOPDIR}/bds-xml/tmp/bds-full.xml
fi
ds_FULL=$3
if test -z "$ds_FULL"; then
  ds_FULL=${TOPDIR}/ds-xml/tmp/ds-full.xml
fi
declare -r ConfigFile="${TOPDIR}/configuration"
declare DepDir="${TOPDIR}/dependencies"
declare LibDir="${TOPDIR}/libs"
declare PackFile="${TOPDIR}/packages.xml"
declare BookXml="${TOPDIR}/book.xml"
declare MakeBook="${TOPDIR}/xsl/make_book.xsl"
declare MakeScripts="${TOPDIR}/xsl/scripts.xsl"
declare BookHtml="${TOPDIR}/book-html"
declare Bds_XML="${TOPDIR}/bds-xml"
declare -a TARGET
declare DEP_LEVEL
declare SUDO
declare LANGUAGE
declare WRAP_INSTALL
declare DEL_LA_FILES
declare STATS

#--------------------------#
parse_configuration() {    #
#--------------------------#
  local	-i cntr=0
  local	-a optTARGET

  while read; do

    # Garbage collection
    case ${REPLY} in
      \#* | '') continue ;;
    esac

    case "${REPLY}" in
      # Create global variables for these parameters.
      optDependency=* | \
      MAIL_SERVER=*   | \
      WRAP_INSTALL=*  | \
      DEL_LA_FILES=*  | \
      STATS=*         | \
      LANGUAGE=*      | \
      SUDO=*  )  eval ${REPLY} # Define/set a global variable..
                      continue ;;
    esac

    if [[ "${REPLY}" =~ ^CONFIG_ ]]; then
      echo "$REPLY"
      optTARGET[$((cntr++))]=$( echo $REPLY | sed -e 's@CONFIG_@@' -e 's@=y@@' )
    fi
  done < $ConfigFile

  if (( $cntr == 0 )); then
    echo -e "\n>>> NO TARGET SELECTED.. application terminated"
    echo -e "    Run <make> again and select (a) package(s) to build\n"
    exit 0
  fi
  TARGET=(${optTARGET[*]})
  DEP_LEVEL=$optDependency
  SUDO=${SUDO:-n}
  WRAP_INSTALL=${WRAP_INSTALL:-n}
  DEL_LA_FILES=${DEL_LA_FILES:-n}
  STATS=${STATS:-n}
}

#--------------------------#
validate_configuration() { #
#--------------------------#
  local -r dotSTR=".................."
  local -r PARAM_LIST="DEP_LEVEL SUDO LANGUAGE MAIL_SERVER WRAP_INSTALL DEL_LA_FILES STATS"
  local -r PARAM_VALS='${config_param}${dotSTR:${#config_param}} ${L_arrow}${BOLD}${!config_param}${OFF}${R_arrow}'
  local config_param
  local -i index

  for config_param in ${PARAM_LIST}; do
    echo -e "`eval echo $PARAM_VALS`"
  done
  for (( index=0 ; index < ${#TARGET[*]} ; index ++ )); do
    echo -e "TARGET${index}${dotSTR:6} ${L_arrow}${BOLD}${TARGET[${index}]}${OFF}${R_arrow}"
  done
}

#
# Generates the root of the dependency tree
#
#--------------------------#
generate_deps() {          #
#--------------------------#

  local -i index
  local DepDir=$1
  rm -f $DepDir/*.{tree,dep}
  for (( index=0 ; index < ${#TARGET[*]} ; index ++ )); do
    echo 1 b ${TARGET[${index}]} >> $DepDir/root.dep
  done
}

#
# Clean configuration file keeping only global default settings.
# That prevent "trying to assign nonexistent symbol" messages
# and assures that there is no TARGET selected from a previous run
#
#--------------------------#
clean_configuration() {    #
#--------------------------#

tail -n 15 ${ConfigFile} > ${ConfigFile}.tmp
mv ${ConfigFile}.tmp ${ConfigFile}

}

#---------------------
# Constants
source ${LibDir}/constants.inc
[[ $? > 0 ]] && echo -e "\n\tERROR: constants.inc did not load..\n" && exit

#---------------------
# Dependencies module
source ${LibDir}/func_dependencies
[[ $? > 0 ]] && echo -e "\n\tERROR: func_dependencies did not load..\n" && exit

#------- MAIN --------
if [[ ! -f ${PackFile} ]] ; then
  echo -e "\tNo packages file has been found.\n"
  echo -e "\tExecution aborted.\n"
  exit 1
fi


parse_configuration
validate_configuration
echo "${SD_BORDER}${nl_}"
echo -n "Are you happy with these settings? yes/no (no): "
read ANSWER
if [ x$ANSWER != "xyes" ] ; then
  echo "${nl_}Rerun make and fix your settings.${nl_}"
  exit 1
fi
echo "${nl_}${SD_BORDER}${nl_}"

rm -rf $DepDir
mkdir $DepDir
generate_deps $DepDir
pushd $DepDir > /dev/null
set +e
generate_subgraph root.dep 1 1 b
echo -e "\n${SD_BORDER}"
echo Graph contains $(ls |wc -l) nodes
echo -e "${SD_BORDER}"
echo Cleaning subgraph...
clean_subgraph
echo done
echo Generating the tree
echo 1 >  root.tree
echo 1 >> root.tree
cat root.dep >> root.tree
generate_dependency_tree root.tree 1
echo -e "\n${SD_BORDER}"
#echo -e \\n provisional end...
#exit
echo Generating the ordered package list
LIST="$(tree_browse root.tree)"
set -e
popd > /dev/null
rm -f ${BookXml}
echo Making XML book
xsltproc --stringparam list    "$LIST"        \
         --stringparam MTA     "$MAIL_SERVER" \
         --stringparam dsbook "$ds_FULL"    \
         -o ${BookXml} \
         ${MakeBook} \
         $Bds_FULL
echo "making HTML book (may take some time...)"
xsltproc -o ${BookHtml}/ \
         -stringparam chunk.quietly 1 \
         ${Bds_XML}/stylesheets/bds-chunked.xsl \
         ${BookXml}
if [ ! -d ${BookHtml}/stylesheets ]
  then mkdir -p ${BookHtml}/stylesheets
  cp ${Bds_XML}/stylesheets/ds-xsl/*.css ${BookHtml}/stylesheets
fi
if [ ! -d ${BookHtml}/images ]
  then mkdir -p ${BookHtml}/images
  cp ${Bds_XML}/images/*.png ${BookHtml}/images
fi
for ht in ${BookHtml}/*.html
  do sed -i 's@\.\./stylesheets@stylesheets@' $ht
  sed -i 's@\.\./images@images@' $ht
done
echo -en "\n\tGenerating the build scripts ...\n"
rm -rf scripts
if test $STATS = y; then
  LIST_STAT="${TARGET[*]}"
else
  LIST_STAT=""
fi
xsltproc --xinclude --nonet \
         --stringparam sudo "$SUDO" \
         --stringparam wrap-install "$WRAP_INSTALL" \
         --stringparam del-la-files "$DEL_LA_FILES" \
         --stringparam list-stat "$LIST_STAT" \
         --stringparam language "$LANGUAGE" \
         -o ./scripts/ ${MakeScripts} \
         ${BookXml}
# Make the scripts executable.
chmod -R +x scripts
echo -e "done\n"

#clean_configuration
