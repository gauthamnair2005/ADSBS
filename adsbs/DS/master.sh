#!/bin/bash


###################################
###	    FUNCTIONS		###
###################################


#############################################################


#----------------------------#
chapter4_Makefiles() {       #
#----------------------------#
  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter4     ( SETUP ) ${R_arrow}"

# If $LUSER_HOME is already present in the host, we asume that the
# ds user and group are also presents in the host, and a backup
# of their bash init files is made.
(
    cat << EOF
020-creatingtoolsdir:
	@\$(call echo_message, Building)
	@mkdir \$(MOUNT_PT)/tools && \\
	rm -f /tools && \\
	ln -s \$(MOUNT_PT)/tools /
	@\$(call housekeeping)

021-addinguser:  020-creatingtoolsdir
	@\$(call echo_message, Building)
	@-if [ ! -d \$(LUSER_HOME) ]; then \\
		groupadd \$(LGROUP); \\
		useradd -s /bin/bash -g \$(LGROUP) -m -k /dev/null \$(LUSER); \\
	else \\
		touch luser-exist; \\
	fi;
	@chown \$(LUSER) \$(MOUNT_PT)/tools && \\
	chmod -R a+wt \$(MOUNT_PT)/\$(SCRIPT_ROOT) && \\
	chmod a+wt \$(SRCSDIR)
	@\$(call housekeeping)

022-settingenvironment:  021-addinguser
	@\$(call echo_message, Building)
	@if [ -f \$(LUSER_HOME)/.bashrc -a ! -f \$(LUSER_HOME)/.bashrc.XXX ]; then \\
		mv \$(LUSER_HOME)/.bashrc \$(LUSER_HOME)/.bashrc.XXX; \\
	fi;
	@if [ -f \$(LUSER_HOME)/.bash_profile  -a ! -f \$(LUSER_HOME)/.bash_profile.XXX ]; then \\
		mv \$(LUSER_HOME)/.bash_profile \$(LUSER_HOME)/.bash_profile.XXX; \\
	fi;
	@echo "set +h" > \$(LUSER_HOME)/.bashrc && \\
	echo "umask 022" >> \$(LUSER_HOME)/.bashrc && \\
	echo "ds=\$(MOUNT_PT)" >> \$(LUSER_HOME)/.bashrc && \\
	echo "LC_ALL=POSIX" >> \$(LUSER_HOME)/.bashrc && \\
	echo "ds_TGT=`uname -m`-ds-linux-gnu" >> \$(LUSER_HOME)/.bashrc && \\
	echo "PATH=/tools/bin:/bin:/usr/bin" >> \$(LUSER_HOME)/.bashrc && \\
	echo "export ds LC_ALL ds_TGT PATH" >> \$(LUSER_HOME)/.bashrc && \\
	echo "source $adsbsDIR/envars" >> \$(LUSER_HOME)/.bashrc && \\
	chown \$(LUSER):\$(LGROUP) \$(LUSER_HOME)/.bashrc && \\
	touch envars && \\
	chown \$(LUSER) envars
	@\$(call housekeeping)
EOF
) > $MKFILE.tmp

  chapter4=" 020-creatingtoolsdir 021-addinguser 022-settingenvironment"
}



#----------------------------#
chapter5_Makefiles() {
#----------------------------#
  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter5     ( LUSER ) ${R_arrow}"

  for file in chapter05/* ; do
    # Keep the script file name
    this_script=`basename $file`

    # If no testsuites are run, then TCL, Expect, DejaGNU and Check
    # aren't needed (but building them does not hurt).
    # Fix also locales creation when running chapter05 testsuites (ugly)
    case "${this_script}" in
#      *tcl)       [[ "${TEST}" = "0" ]] && continue ;;
#      *expect)    [[ "${TEST}" = "0" ]] && continue ;;
#      *dejagnu)   [[ "${TEST}" = "0" ]] && continue ;;
#      *check)     [[ "${TEST}" = "0" ]] && continue ;;
# We now do that in ds.xsl, because stripping.xml contains other cleaning
# instructions
#      *stripping) [[ "${STRIP}" = "n" ]] && continue ;;
      *glibc)     [[ "${TEST}" = "3" ]] && \
                  sed -i 's@/usr/lib/locale@/tools/lib/locale@' $file ;;
    esac

    # First append each name of the script files to a list (this will become
    # the names of the targets in the Makefile
    # DO NOT append the changingowner script, it need be run as root.
    # A hack is necessary: create script in chap5 BUT run as a dependency for
    # SUDO target
    case "${this_script}" in
      *changingowner) runasroot="$runasroot ${this_script}" ;;
                   *) chapter5="$chapter5 ${this_script}" ;;
    esac

    # Grab the name of the target (minus the -pass1 or -pass2 in the case of gcc
    # and binutils in chapter 5)
    name=`echo ${this_script} | sed -e 's@[0-9]\{3\}-@@' \
                                    -e 's@-pass[0-9]\{1\}@@' \
                                    -e 's@-libstdc++@@'`

    # Set the dependency for the first target.
    if [ -z $PREV ] ; then PREV=022-settingenvironment ; fi

    #--------------------------------------------------------------------#
    #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
    #--------------------------------------------------------------------#
    #
    # Find the name of the tarball and the version of the package
    pkg_tarball=$(sed -n 's/tar -xf \(.*\)/\1/p' $file)
    pkg_version=$(sed -n 's/VERSION=\(.*\)/\1/p' $file)

    # Drop in the name of the target on a new line, and the previous target
    # as a dependency. Also call the echo_message function.
    LUSER_wrt_target "${this_script}" "$PREV" "$pkg_version"

    # If $pkg_tarball isn't empty, we've got a package...
    if [ "$pkg_tarball" != "" ] ; then
      # Always initialize the log file, since the test instructions may be
      # "uncommented" by the user
      LUSER_wrt_test_log "${this_script}" "$pkg_version"
      # If using optimizations, write the instructions
      case "${OPTIMIZE}${this_script}${REALSBU}" in
          *binutils-pass1y) ;;
          2*) wrt_optimize "$name" && wrt_makeflags "$name" ;;
          *) ;;
      esac
    fi

    # Insert date and disk usage at the top of the log file, the script run
    # and date and disk usage again at the bottom of the log file.
    # The changingowner script must be run as root.
    case "${this_script}" in
      *changingowner)  wrt_RunAsRoot "$file" "$pkg_version" ;;
      *)               LUSER_wrt_RunAsUser "$file" "$pkg_version" ;;
    esac

    # Include a touch of the target name so make can check
    # if it's already been made.
    wrt_touch
    #
    #--------------------------------------------------------------------#
    #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
    #--------------------------------------------------------------------#

    # Keep the script file name for Makefile dependencies.
    PREV=${this_script}
  done  # end for file in chapter05/*
}


#----------------------------#
chapter6_Makefiles() {
#----------------------------#

  # Set envars and scripts for iteration targets
  if [[ -z "$1" ]] ; then
    local N=""
  else
    local N=-build_$1
    local chapter6=""
    mkdir chapter06$N
    cp chapter06/* chapter06$N
    for script in chapter06$N/* ; do
      # Overwrite existing symlinks, files, and dirs
      sed -e 's/ln *-sv/&f/g' \
          -e 's/mv *-v/&f/g' \
          -e 's/mkdir *-v/&p/g' -i ${script}
      # Suppress the mod of "test-installation.pl" because now
      # the library path points to /usr/lib
      if [[ ${script} =~ glibc ]]; then
          sed '/DL=/,/unset DL/d' -i ${script}
      fi
      # Rename the scripts
      mv ${script} ${script}$N
    done
    # Remove Bzip2 binaries before make install (ds-6.2 compatibility)
    sed -e 's@make install@rm -vf /usr/bin/bz*\n&@' -i chapter06$N/*-bzip2$N
  fi

  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter6$N     ( CHROOT ) ${R_arrow}"

  for file in chapter06$N/* ; do
    # Keep the script file name
    this_script=`basename $file`

    # Skip the "stripping" scripts if the user does not want to strip.
    # Skip also linux-headers in iterative builds.
    case "${this_script}" in
      *stripping*) [[ "${STRIP}" = "n" ]] && continue ;;
      *linux-headers*) [[ -n "$N" ]] && continue ;;
    esac

    # Grab the name of the target.
    name=`echo ${this_script} | sed -e 's@[0-9]\{3\}-@@' -e 's,'$N',,'`

    # Find the tarball corresponding to our script.
    # If it doesn't, we skip it in iterations rebuilds (except stripping).
    pkg_tarball=$(sed -n 's/tar -xf \(.*\)/\1/p' $file)
    pkg_version=$(sed -n 's/VERSION=\(.*\)/\1/p' $file)

    if [[ "$pkg_tarball" = "" ]] && [[ -n "$N" ]] ; then
      case "${this_script}" in
        *stripping*) ;;
        *)  continue ;;
      esac
    fi

    # Append each name of the script files to a list (this will become
    # the names of the targets in the Makefile)
    # The kernfs script must be run as part of SUDO target.
    case "${this_script}" in
      *kernfs) runasroot="$runasroot ${this_script}" ;;
            *) chapter6="$chapter6 ${this_script}" ;;
    esac

    #--------------------------------------------------------------------#
    #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
    #--------------------------------------------------------------------#
    #
    # Drop in the name of the target on a new line, and the previous target
    # as a dependency. Also call the echo_message function.
    # In the mount of kernel filesystems we need to set ds
    # and not to use chroot.
    case "${this_script}" in
      *kernfs)  LUSER_wrt_target  "${this_script}" "$PREV" "$pkg_version" ;;
      *)        CHROOT_wrt_target "${this_script}" "$PREV" "$pkg_version" ;;
    esac

    # If $pkg_tarball isn't empty, we've got a package...
    # Insert instructions for unpacking the package and changing directories
    if [ "$pkg_tarball" != "" ] ; then
      # Touch timestamp file if installed files logs will be created.
      # But only for the firt build when running iterative builds.
      if [ "${INSTALL_LOG}" = "y" ] && [ "x${N}" = "x" ] ; then
        CHROOT_wrt_TouchTimestamp
      fi
      # Always initialize the log file, so that the use may reinstate a
      # commented out test
      CHROOT_wrt_test_log "${this_script}" "$pkg_version"
      # If using optimizations, write the instructions
      [[ "$OPTIMIZE" != "0" ]] &&  wrt_optimize "$name" && wrt_makeflags "$name"
    fi

    # In the mount of kernel filesystems we need to set ds
    # and not to use chroot.
    case "${this_script}" in
      *kernfs)  wrt_RunAsRoot  "$file" "$pkg_version" ;;
      *)        CHROOT_wrt_RunAsRoot "$file" "$pkg_version" ;;
    esac

    # Write installed files log and remove the build directory(ies)
    # except if the package build fails.
    if [ "$pkg_tarball" != "" ] ; then
      if [ "${INSTALL_LOG}" = "y" ] && [ "x${N}" = "x" ] ; then
        CHROOT_wrt_LogNewFiles "$name"
      fi
    fi

    # Include a touch of the target name so make can check
    # if it's already been made.
    wrt_touch
    #
    #--------------------------------------------------------------------#
    #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
    #--------------------------------------------------------------------#

    # Keep the script file name for Makefile dependencies.
    PREV=${this_script}
    # Set system_build envar for iteration targets
    system_build=$chapter6
  done # end for file in chapter06/*
}

#----------------------------#
chapter78_Makefiles() {
#----------------------------#
  echo "${tab_}${GREEN}Processing... ${L_arrow}Chapter7/8   ( BOOT ) ${R_arrow}"

  for file in chapter0{7,8}/* ; do
    # Keep the script file name
    this_script=`basename $file`

    # Grub must be configured manually.
    # Handle fstab creation.
    # If no .config file is supplied, the kernel build is skipped
    case ${this_script} in
      *grub)    continue ;;
      *fstab)   [[ -z "${FSTAB}" ]] ||
                [[ ${FSTAB} == $BUILDDIR/sources/fstab ]] ||
                cp ${FSTAB} $BUILDDIR/sources/fstab ;;
      *kernel)  [[ -z ${CONFIG} ]] && continue
                [[ ${CONFIG} == $BUILDDIR/sources/kernel-config ]] ||
                cp ${CONFIG} $BUILDDIR/sources/kernel-config  ;;
    esac

    # First append each name of the script files to a list (this will become
    # the names of the targets in the Makefile
    chapter78="$chapter78 ${this_script}"

    #--------------------------------------------------------------------#
    #         >>>>>>>> START BUILDING A Makefile ENTRY <<<<<<<<          #
    #--------------------------------------------------------------------#
    #
    # Drop in the name of the target on a new line, and the previous target
    # as a dependency. Also call the echo_message function.
    CHROOT_wrt_target "${this_script}" "$PREV"

    # Find the bootscripts or networkscripts (for systemd)
    # and kernel package names
    case "${this_script}" in
      *bootscripts)
            name="ds-bootscripts"
            if [ "${INSTALL_LOG}" = "y" ] ; then
              CHROOT_wrt_TouchTimestamp
            fi
        ;;
      *network-scripts)
            name="ds-network-scripts"
            if [ "${INSTALL_LOG}" = "y" ] ; then
              CHROOT_wrt_TouchTimestamp
            fi
        ;;
      *kernel)
            name="linux"
            if [ "${INSTALL_LOG}" = "y" ] ; then
              CHROOT_wrt_TouchTimestamp
            fi
            # If using optimizations, use MAKEFLAGS (unless blacklisted)
            # no setting of CFLAGS and friends.
            [[ "$OPTIMIZE" != "0" ]] &&  wrt_makeflags "$name"
       ;;
    esac

      # Check if we have a real /etc/fstab file
    case "${this_script}" in
      *fstab) if [[ -n "$FSTAB" ]]; then
                CHROOT_wrt_CopyFstab
              else
                CHROOT_wrt_RunAsRoot "$file"
              fi
        ;;
      *)        CHROOT_wrt_RunAsRoot "$file"
        ;;
    esac

    case "${this_script}" in
      *bootscripts|*network-scripts|*kernel)
                         if [ "${INSTALL_LOG}" = "y" ] ; then
                           CHROOT_wrt_LogNewFiles "$name"
                         fi ;;
    esac
    # Include a touch of the target name so make can check
    # if it's already been made.
    wrt_touch
    #
    #--------------------------------------------------------------------#
    #              >>>>>>>> END OF Makefile ENTRY <<<<<<<<               #
    #--------------------------------------------------------------------#

    # Keep the script file name for Makefile dependencies.
    PREV=${this_script}
  done  # for file in chapter0{7,8}/*

}



#----------------------------#
build_Makefile() {           #
#----------------------------#

  echo "Creating Makefile... ${BOLD}START${OFF}"

  cd $adsbsDIR/${PROGNAME}-commands

  # Start with a clean Makefile.tmp file
  >$MKFILE

  chapter4_Makefiles
  chapter5_Makefiles
  chapter6_Makefiles
  # Add the iterations targets, if needed
  [[ "$COMPARE" = "y" ]] && wrt_compare_targets
  chapter78_Makefiles
  # Add the CUSTOM_TOOLS targets, if needed
  [[ "$CUSTOM_TOOLS" = "y" ]] && wrt_CustomTools_target

  # Add a header, some variables and include the function file
  # to the top of the real Makefile.
  wrt_Makefile_header

  # Add chroot commands
  CHROOT_LOC="`whereis -b chroot | cut -d " " -f2`"
  i=1
  for file in ../chroot-scripts/*chroot* ; do
    chroot=`cat $file | \
            perl -pe 's|\\\\\n||g' | \
            tr -s [:space:] | \
            grep chroot | \
            sed -e "s|chroot|$CHROOT_LOC|" \
                -e 's|\\$|&&|g' \
                -e 's|"$$ds"|$(MOUNT_PT)|'`
    echo -e "CHROOT$i= $chroot\n" >> $MKFILE
    i=`expr $i + 1`
  done

  # Store virtual kernel file systems commands:
  devices=`cat ../kernfs-scripts/devices.sh | \
            sed -e 's|^|	|'   \
                -e 's|mount|sudo &|' \
                -e 's|mkdir|sudo &|' \
                -e 's|\\$|&&|g' \
                -e 's|\$|; \\\\|' \
                -e 's|then|& :|' \
                -e 's|\$\$ds|$(MOUNT_PT)|g'`
  teardown=`cat ../kernfs-scripts/teardown.sh | \
            sed -e 's|^|	|'   \
                -e 's|umount|sudo &|' \
                -e 's|\$ds|$(MOUNT_PT)|'`
  teardownat=`cat ../kernfs-scripts/teardown.sh | \
              sed -e 's|^|	|'   \
                  -e 's|umount|@-sudo &|' \
                  -e 's|\$ds|$(MOUNT_PT)|'`
  # Drop in the main target 'all:' and the chapter targets with each sub-target
  # as a dependency.
(
    cat << EOF

all:	ck_UID mk_SETUP mk_LUSER mk_SUDO mk_CHROOT mk_BOOT create-sbu_du-report mk_Bds_TOOL mk_CUSTOM_TOOLS
$teardownat
	@sudo make do_housekeeping
EOF
) >> $MKFILE
if [ "$INITSYS" = systemd ]; then
(
    cat << EOF
	@/bin/echo -e -n \\
	NAME=\\"Linux From Scratch\\"\\\\n\\
	VERSION=\\"$VERSION\\"\\\\n\\
	ID=ds\\\\n\\
	PRETTY_NAME=\\"Linux From Scratch $VERSION\\"\\\\n\\
	VERSION_CODENAME=\\"$(whoami)-adsbs\\"\\\\n\\
	> os-release && \\
	sudo mv os-release \$(MOUNT_PT)/etc && \\
	sudo chown root:root \$(MOUNT_PT)/etc/os-release
EOF
) >> $MKFILE
fi
(
    cat << EOF
	@echo $VERSION > ds-release && \\
	sudo mv ds-release \$(MOUNT_PT)/etc && \\
	sudo chown root:root \$(MOUNT_PT)/etc/ds-release
	@/bin/echo -e -n \\
	DISTRIB_ID=\\"Linux From Scratch\\"\\\\n\\
	DISTRIB_RELEASE=\\"$VERSION\\"\\\\n\\
	DISTRIB_CODENAME=\\"$(whoami)-adsbs\\"\\\\n\\
	DISTRIB_DESCRIPTION=\\"Linux From Scratch\\"\\\\n\\
	> lsb-release && \\
	sudo mv lsb-release \$(MOUNT_PT)/etc && \\
	sudo chown root:root \$(MOUNT_PT)/etc/lsb-release
	@\$(call echo_finished,$VERSION)

ck_UID:
	@if [ \`id -u\` = "0" ]; then \\
	  echo "--------------------------------------------------"; \\
	  echo "You cannot run this makefile from the root account"; \\
	  echo "--------------------------------------------------"; \\
	  exit 1; \\
	fi

mk_SETUP:
	@\$(call echo_SU_request)
	@sudo make BREAKPOINT=\$(BREAKPOINT) SETUP
	@touch \$@

mk_LUSER: mk_SETUP
	@\$(call echo_SULUSER_request)
	@( \$(SU_LUSER) "make -C \$(MOUNT_PT)/\$(SCRIPT_ROOT) BREAKPOINT=\$(BREAKPOINT) LUSER" )
	@sudo make restore-luser-env
	@touch \$@

mk_SUDO: mk_LUSER
	@sudo make BREAKPOINT=\$(BREAKPOINT) SUDO
	@touch \$@

mk_CHROOT: mk_SUDO
	@\$(call echo_CHROOT_request)
	@( sudo \$(CHROOT1) -c "cd \$(SCRIPT_ROOT) && make BREAKPOINT=\$(BREAKPOINT) CHROOT")
	@touch \$@

mk_BOOT: mk_CHROOT
	@\$(call echo_CHROOT_request)
	@( sudo \$(CHROOT2) -c "cd \$(SCRIPT_ROOT) && make BREAKPOINT=\$(BREAKPOINT) BOOT")
	@touch \$@

mk_Bds_TOOL: create-sbu_du-report
	@if [ "\$(ADD_Bds_TOOLS)" = "y" ]; then \\
	  \$(call sh_echo_PHASE,Building Bds_TOOL); \\
	  (sudo \$(CHROOT2) -c "make -C $Bds_ROOT/work"); \\
	fi;
	@touch \$@

mk_CUSTOM_TOOLS: mk_Bds_TOOL
	@if [ "\$(ADD_CUSTOM_TOOLS)" = "y" ]; then \\
	  \$(call sh_echo_PHASE,Building CUSTOM_TOOLS); \\
	  sudo mkdir -p ${BUILDDIR}${TRACKING_DIR}; \\
	  (sudo \$(CHROOT2) -c "cd \$(SCRIPT_ROOT) && make BREAKPOINT=\$(BREAKPOINT) CUSTOM_TOOLS"); \\
	fi;
	@touch \$@

devices: ck_UID
$devices
EOF
) >> $MKFILE
if [ "$INITSYS" = systemd ]; then
(
    cat << EOF
	sudo mkdir -pv \$(MOUNT_PT)/run/systemd/resolve
	sudo cp -v /etc/resolv.conf \$(MOUNT_PT)/run/systemd/resolve
EOF
) >> $MKFILE
fi
(
    cat << EOF

teardown:
$teardown

chroot1: devices
	sudo \$(CHROOT1)
	\$(MAKE) teardown

chroot: devices
	sudo \$(CHROOT2)
	\$(MAKE) teardown

SETUP:        $chapter4
LUSER:        $chapter5
SUDO:         $runasroot
EOF
) >> $MKFILE
if [ "$INITSYS" = systemd ]; then
(
    cat << EOF
	mkdir -pv \$(MOUNT_PT)/run/systemd/resolve
	cp -v /etc/resolv.conf \$(MOUNT_PT)/run/systemd/resolve

EOF
) >> $MKFILE
fi
(
    cat << EOF
CHROOT:       SHELL=/tools/bin/bash
CHROOT:       $chapter6
BOOT:         $chapter78
CUSTOM_TOOLS: $custom_list


create-sbu_du-report:  mk_BOOT
	@\$(call echo_message, Building)
	@if [ "\$(ADD_REPORT)" = "y" ]; then \\
	  sudo ./create-sbu_du-report.sh logs $VERSION $(date --iso-8601); \\
	  \$(call echo_report,$VERSION-SBU_DU-$(date --iso-8601).report); \\
	fi;
	@touch  \$@

restore-luser-env:
	@\$(call echo_message, Building)
	@if [ -f \$(LUSER_HOME)/.bashrc.XXX ]; then \\
		mv -f \$(LUSER_HOME)/.bashrc.XXX \$(LUSER_HOME)/.bashrc; \\
	fi;
	@if [ -f \$(LUSER_HOME)/.bash_profile.XXX ]; then \\
		mv \$(LUSER_HOME)/.bash_profile.XXX \$(LUSER_HOME)/.bash_profile; \\
	fi;
	@chown \$(LUSER):\$(LGROUP) \$(LUSER_HOME)/.bash*
	@\$(call housekeeping)

do_housekeeping:
	@-rm /tools
	@-if [ ! -f luser-exist ]; then \\
		userdel \$(LUSER); \\
		rm -rf \$(LUSER_HOME); \\
	fi;

EOF
) >> $MKFILE

  # Bring over the items from the Makefile.tmp
  cat $MKFILE.tmp >> $MKFILE
  rm $MKFILE.tmp
  echo "Creating Makefile... ${BOLD}DONE${OFF}"
}
