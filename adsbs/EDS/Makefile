# From the Build Scripts Written By: Jim Gifford <ds@jg555.com>
# Modified By: Joe Ciccone <jciccone@linuxfromscratch.org>
# Additional changes: George Boudreau <georgeb@linuxfromscratch.org>
#                     Pierre Labastie <pierre.labastie at neuf.fr>


ifdef V
  Q =
else
  Q = @
endif

# Known behavior
LANG=C
LC_ALL=C

# Makefile should reside in a directory where there are two subdirectories
# initially:
TOPDIR           = $(shell pwd)
# the stylesheets
XSLDIR           = $(TOPDIR)/xsl
# the menu program sources
MENU             = $(TOPDIR)/menu

# Those directories and files will be created and populated by make:
# directory of the book sources:
ds_XML          = $(TOPDIR)/ds-xml
Bds_XML         = $(TOPDIR)/bds-xml
# contains the REV used in the preceding call:
REVFILE          = $(TOPDIR)/revision
# the list of packages:
PACK_LIST        = $(TOPDIR)/packages.xml
# the generated menu input:
CONFIG_CONFIG_IN = $(TOPDIR)/Config.in
# menu output:
CONFIG_OUT       = $(TOPDIR)/configuration
# the linear book:
BOOK_XML         = $(TOPDIR)/book.xml

dsTMP           = $(ds_XML)/tmp
RENDERTMP        = $(Bds_XML)/tmp
ds_FULL         = $(dsTMP)/ds-full.xml
Bds_FULL        = $(RENDERTMP)/bds-full.xml

# The right-hand side is updated by adsbs:
# Where the tracking file resides:
TRACKING_DIR = tracking-dir

# Will be created  by make, if not existent
TRACKFILE        = $(TRACKING_DIR)/instpkg.xml

# Initial content of the tracking file
define INITIAL_TRACK
<?xml version="1.0" encoding="ISO-8859-1"?>\n\
\n\
<!DOCTYPE sublist SYSTEM "$(TOPDIR)/packdesc.dtd">\n\
<sublist>\n\
  <name>Installed</name>\n\
</sublist>
endef

ds-SVN = svn://svn.linuxfromscratch.org/ds/trunk/BOOK
SVN = svn://svn.linuxfromscratch.org/Bds/trunk/BOOK

ALLXML := $(filter-out $(RENDERTMP)/%, \
              $(shell if [ -d $(Bds_XML) ]; then \
                        find $(Bds_XML) -name \*.xml; \
                      fi))
ALLXMLds:= $(filter-out $(dsTMP)/%, \
              $(shell if [ -d $(ds_XML) ]; then \
                        find $(ds_XML) -name \*.xml; \
                      fi))
ALLXSL := $(filter-out $(RENDERTMP)/%, \
              $(shell if [ -d $(Bds_XML) ]; then \
                        find $(Bds_XML) -name \*.xsl; \
                      fi))
ALLXSLds := $(filter-out $(dsTMP)/%, \
              $(shell if [ -d $(ds_XML) ]; then \
                        find $(ds_XML) -name \*.xsl; \
                      fi))

# Try to set the REV variable according to previous runs, except when
# set on the command line:
REV1 := $(shell if [ -f $(REVFILE) ] ; then cat $(REVFILE); fi)
ifneq ($(origin REV),command line)
  ifdef REV1
    REV = $(REV1)
  else
    REV = not defined
  endif
endif

ifneq ($(REV),sysv)
  ifneq ($(REV),systemd)
    $(error The REV variable is $(REV), but can only be 'sysv' or 'systemd')
  endif
endif

$(BOOK_XML): $(CONFIG_OUT)
	$(Q)$(TOPDIR)/gen_pkg_book.sh $(TOPDIR) $(Bds_FULL) $(ds_FULL)

$(CONFIG_OUT): $(CONFIG_CONFIG_IN)
	$(Q)CONFIG_="" KCONFIG_CONFIG=configuration \
	    $(MENU)/menuconfig.py $(CONFIG_CONFIG_IN)

$(CONFIG_CONFIG_IN): $(PACK_LIST) $(XSLDIR)/gen_config.xsl
	$(Q)xsltproc --nonet -o $@ $(XSLDIR)/gen_config.xsl $(PACK_LIST)

$(PACK_LIST): $(XSLDIR)/gen_pkg_list.xsl $(XSLDIR)/specialCases.xsl $(TRACKFILE) $(ds_FULL)
	$(Q)xsltproc --stringparam installed-packages $(TRACKFILE) \
	--stringparam ds-full $(ds_FULL) \
	-o $@.tmp $(XSLDIR)/gen_pkg_list.xsl $(Bds_FULL)
	$(Q)xmllint --postvalid --format -o $@ $@.tmp
	$(Q)rm $@.tmp

# Beware of the echo '$(INITIAL_TRACK)' command below:
# if shell is bash or sh linked to bash, needs echo -e
# if shell is dash or sh linked to dash: echo is enough
# Don't ask me why
# So use /bin/echo (needs -e)
$(TRACKFILE): $(TRACKING_DIR)
	$(Q)if ! [ -f $@ ]; then \
	echo Initializing $(TRACKFILE) && \
	/bin/echo -e '$(INITIAL_TRACK)' > $@; \
	fi
	$(Q)for track in $(TRACKING_DIR)/*-*; do \
	if [ -f $$track ]; then \
	pack=$$(echo $$track | sed 's@.*/\(.*\)-[0-9c].*@\1@') && \
	version=$$(echo $$track | sed 's@.*-\([0-9c].*\)@\1@') && \
	xsltproc --stringparam packages $(PACK_LIST) \
	--stringparam package $$pack \
	--stringparam version $$version \
	-o track.tmp $(XSLDIR)/bump.xsl $@ && \
	sed -i 's@PACKDESC@$(TOPDIR)/packdesc.dtd@' track.tmp && \
	xmllint --format --postvalid track.tmp > $@; \
	fi; \
	rm -f $$track; \
	done; \
	rm -f track.tmp

$(TRACKING_DIR):
	@echo Creating $(TRACKING_DIR)
	$(Q)mkdir -p $@

$(XSLDIR)/specialCases.xsl: $(TOPDIR)/gen-special.sh $(Bds_FULL)
	$(Q)$(TOPDIR)/gen-special.sh $(Bds_FULL) $@

ifneq ($(REV),$(REV1))
$(Bds_FULL): FORCE
$(ds_FULL): FORCE
endif
$(ds_FULL): $(ds_XML) $(ds_XML)/general.ent $(ALLXMLds) $(ALLXSLds)
	@echo "Processing ds bootscripts..."
	$(Q)cd $(ds_XML) && bash process-scripts.sh
	$(Q)[ -d $(dsTMP) ] || mkdir -p $(dsTMP)
	@echo "Adjusting ds for revision $(REV)..."
	$(Q)xsltproc --nonet --xinclude                          \
	             --stringparam profile.revision $(REV)       \
	             --output $(dsTMP)/ds-prof.xml         \
	             $(ds_XML)/stylesheets/ds-xsl/profile.xsl \
	             $(ds_XML)/index.xml
	@echo "Validating the ds book..."
	$(Q)xmllint --nonet --noent --postvalid \
	  -o $@ $(dsTMP)/ds-prof.xml
	$(Q)rm -f $(ds_XML)/appendices/*.script
	$(Q)cd $(ds_XML) && ./aux-file-data.sh $@
	$(Q)echo $(REV) > $(REVFILE)

$(Bds_FULL): $(Bds_XML) $(Bds_XML)/general.ent $(ALLXML) $(ALLXSL)
	$(Q)[ -d $(RENDERTMP) ] || mkdir -p $(RENDERTMP)
	@echo "Adjusting Bds for revision $(REV)..."
	$(Q)xsltproc --nonet --xinclude                          \
	             --stringparam profile.revision $(REV)       \
	             --output $(RENDERTMP)/bds-prof.xml         \
	             $(Bds_XML)/stylesheets/ds-xsl/profile.xsl \
	             $(Bds_XML)/index.xml
	@echo "Validating the Bds book..."
	$(Q)xmllint --nonet --noent --postvalid \
	  -o $@ $(RENDERTMP)/bds-prof.xml
	$(Q)echo $(REV) > $(REVFILE)

all: update $(BOOK_XML)

update: $(Bds_XML) $(ds_XML)
	@echo Updating the book sources
	$(Q)cd $(ds_XML) && svn up
	$(Q)cd $(Bds_XML) && svn up

$(ds_XML):
	@echo Getting the ds book sources...
	$(Q)svn co $(ds-SVN) $@

$(Bds_XML):
	@echo Getting the Bds book sources...
	$(Q)svn co $(SVN) $@

# Clean up

clean:
	rm -f $(CONFIG_OUT) $(CONFIG_OUT).old $(TOPDIR)/packages.xml $(XSLDIR)/specialCases.xsl $(CONFIG_CONFIG_IN) book.xml
	rm -rf $(TOPDIR)/dependencies $(TOPDIR)/book-html $(TOPDIR)/scripts

FORCE:
.PHONY: clean all update $(CONFIG_OUT) FORCE
