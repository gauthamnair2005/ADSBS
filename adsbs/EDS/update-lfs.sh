#!/bin/bash


# Fills the tracking file with versions of ds packages taken from an
# SVN repository, at either a given date or a given tag (argument $1).
#------
# Argument $1:
# $1 contains a tag or a date, to indicate which version of the ds book
# to use. It may be empty, meaning to use whatever version is presently in
# ds-xml.
#
# It is recognized as a tag if it begins with x.y, where 'x' is one or more
# digit(s), the '.' (dot) is mandatory, an 'y' is one or more digits. Anything
# after y is allowed (for example 7.6-systemd or 8.1-rc1).
#
# It is recognized as a date if it is exactly 8 digits. Then it is assumed that
# the format is YYYYMMDD.
#
# Note that there is no check that the tag or the date are valid. Svn errors
# out if the tag is not valid, and if the date is impossible (that is MM>12
# or DD>31), but it happily accepts YYYY=3018 (and updates to HEAD).
#------
# The tracking file is taken from Makefile in the same directory.

MYDIR=$( cd $(dirname $0); pwd )
ds_XML=${MYDIR}/ds-xml

if [ -z "$1" ]; then # use ds-xml as is
    DO_COMMANDS=n
elif [ "$(echo $1 | sed 's/^[[:digit:]]\+\.[[:digit:]]\+//')" != "$1" ]
    then # tag
    DO_COMMANDS=y
    CURR_SVN=$(cd $ds_XML; LANG=C svn info | sed -n 's/Relative URL: //p')
    CURR_REV=$(cd $ds_XML; LANG=C svn info | sed -n 's/Revision: //p')
    BEG_COMMAND="(cd $ds_XML; svn switch ^/tags/$1)"
    END_COMMAND="(cd $ds_XML; svn switch $CURR_SVN@$CURR_REV)"
elif [ "$(echo $1 | sed 's/^[[:digit:]]\{8\}$//')" != "$1" ]; then # date
    DO_COMMANDS=y
    CURR_REV=$(cd $ds_XML; LANG=C svn info | sed -n 's/Revision: //p')
    BEG_COMMAND="(cd $ds_XML; svn update -r\\{$1\\})"
    END_COMMAND="(cd $ds_XML; svn update -r$CURR_REV)"
else
    echo Bad format in $1: must be a x.y[-aaa] tag or a YYYYMMDD date
    exit 1
fi

if [ -f $MYDIR/Makefile ]; then
    TRACKING_DIR=$(sed -n 's/TRACKING_DIR[ ]*=[ ]*//p' $MYDIR/Makefile)
    TRACKFILE=${TRACKING_DIR}/instpkg.xml
else
    echo The directory where $0 resides does not contain a Makefile
    exit 1
fi

# We need to know the revision to generate the correct ds-full...
if [ ! -r $MYDIR/revision ]; then
    echo $MYDIR/revision is not available
    exit 1
fi
REVISION=$(cat $MYDIR/revision)
#Debug
#echo BEG_COMMAND = $BEG_COMMAND
#echo Before BEG_COMMAND
#( cd $ds_XML; LANG=C svn info )
#End debug

if [ "$DO_COMMANDS"=y ]; then
    echo Running: $BEG_COMMAND
    eval $BEG_COMMAND
fi

# Update code
ds_FULL=/tmp/ds-full.xml
echo Creating $ds_FULL with information from $ds_XML
echo "Processing ds bootscripts..."
( cd $ds_XML && bash process-scripts.sh )
echo "Adjusting ds for revision $REVISION..."
xsltproc --nonet --xinclude                          \
         --stringparam profile.revision $REVISION       \
         --output /tmp/ds-prof.xml         \
        $ds_XML/stylesheets/ds-xsl/profile.xsl \
        $ds_XML/index.xml
echo "Validating the ds book..."
xmllint --nonet --noent --postvalid \
        -o $ds_FULL /tmp/ds-prof.xml
rm -f $ds_XML/appendices/*.script
( cd $ds_XML && ./aux-file-data.sh $ds_FULL )

echo Updating ${TRACKFILE} with information taken from $ds_FULL
echo -n "Is it OK? yes/no (no): "
read ANSWER
#Debug
echo You answered $ANSWER
#End debug

if [ x$ANSWER = "xyes" ] ; then
    for pack in $(grep '<productname' $ds_FULL |
                  sed 's/.*>\([^<]*\)<.*/\1/' |
                  sort | uniq); do
        if [ "$pack" = "libstdc++" -o \
             "$pack" = "tcl"       -o \
             "$pack" = "tcl-core"  -o \
             "$pack" = "expect"    -o \
             "$pack" = "dejagnu"      ]; then continue; fi
        VERSION=$(grep -A1 ">$pack</product" $ds_FULL |
                    head -n2 |
                    sed -n '2s/.*>\([^<]*\)<.*/\1/p')
#Debug
echo $pack: $VERSION
#End debug
        xsltproc --stringparam packages $MYDIR/packages.xml \
                 --stringparam package $pack \
                 --stringparam version $VERSION \
                 -o track.tmp \
                 $MYDIR/xsl/bump.xsl ${TRACKFILE}
        sed -i "s@PACKDESC@$MYDIR/packdesc.dtd@" track.tmp
        xmllint --format --postvalid track.tmp > ${TRACKFILE}
        rm track.tmp
    done
    VERSION=$(grep 'echo.*ds-release' $ds_FULL |
              sed 's/.*echo[ ]*\([^ ]*\).*/\1/')
#Debug
echo ds-Release: $VERSION
#End debug
    xsltproc --stringparam packages $MYDIR/packages.xml \
             --stringparam package ds-Release \
             --stringparam version $VERSION \
             -o track.tmp \
             $MYDIR/xsl/bump.xsl ${TRACKFILE}
    sed -i "s@PACKDESC@$MYDIR/packdesc.dtd@" track.tmp
    xmllint --format --postvalid track.tmp > ${TRACKFILE}
    rm track.tmp
fi
#Debug
#echo After BEG_COMMAND\; before END_COMMAND
#( cd $ds_XML; LANG=C svn info )
#End debug


if [ "$DO_COMMANDS"=y ]; then
    echo Running: $END_COMMAND
    eval $END_COMMAND
fi

#Debug
#echo After END_COMMAND
#( cd $ds_XML; LANG=C svn info )
#End debug
