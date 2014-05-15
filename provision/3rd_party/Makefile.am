SUBDIRS = GPL BSD

SYSLINUXTARGETS = lpxelinux.0 pxelinux.0 ldlinux.c32

MAINTAINERCLEANFILES = Makefile.in

all: $(SYSLINUXTARGETS)

SYSLINUX_VERSION = 6.02
SYSLINUX_SOURCE = $(top_srcdir)/3rd_party/GPL/syslinux-$(SYSLINUX_VERSION).tar.bz2
SYSLINUX_DIR = syslinux-$(SYSLINUX_VERSION)


syslinuxprepare:
	@ if [ ! -d "_work/$(SYSLINUX_DIR)" ]; then \
		echo "Extracting syslinux distribution" ;\
		mkdir -p _work/ ;\
		tar xjf $(SYSLINUX_SOURCE) -C _work/ ;\
	fi
	touch prepare

lpxelinux.0: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/bios/core/lpxelinux.0 .

ldlinux.c32: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/bios/com32/elflink/ldlinux/ldlinux.c32 .

pxelinux.0: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/bios/core/pxelinux.0 .

install-data-local: $(SYSLINUXTARGETS)
	mkdir -p $(DESTDIR)/$(datadir)/warewulf/
	@ for i in $(SYSLINUXTARGETS); do \
		install -m 644 $$i $(DESTDIR)/$(datadir)/warewulf/ ; \
	done

uninstall-local:
	@ for i in $(SYSLINUXTARGETS); do \
		rm -f $(DESTDIR)/$(datadir)/warewulf/$$i ; \
	done
	rm -f prepare

clean-local:
	rm -rf _work prepare $(SYSLINUXTARGETS)
