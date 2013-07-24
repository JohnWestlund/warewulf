SUBDIRS = GPL BSD

MAINTAINERCLEANFILES = Makefile.in

all: pxelinux.0 chain.c32

SYSLINUX_VERSION = 5.01
SYSLINUX_SOURCE = $(top_srcdir)/3rd_party/GPL/syslinux-$(SYSLINUX_VERSION).tar.bz2
SYSLINUX_DIR = syslinux-$(SYSLINUX_VERSION)

chain.c32:
	@ if [ ! -d "_work/$(SYSLINUX_DIR)" ]; then \
		echo "Extracting syslinux distribution" ;\
		mkdir -p _work/ ;\
		tar xjf $(SYSLINUX_SOURCE) -C _work/ ;\
	fi
	cp _work/$(SYSLINUX_DIR)/com32/chain/chain.c32 .
	cp _work/$(SYSLINUX_DIR)/com32/libutil/libutil.c32 .
	cp _work/$(SYSLINUX_DIR)/com32/lib/libcom32.c32 .

pxelinux.0:
	@ if [ ! -d "_work/$(SYSLINUX_DIR)" ]; then \
		echo "Extracting syslinux distribution" ;\
		mkdir -p _work/ ;\
		tar xjf $(SYSLINUX_SOURCE) -C _work/ ;\
	fi
	cp _work/$(SYSLINUX_DIR)/core/pxelinux.0 .
	cp _work/$(SYSLINUX_DIR)/com32/elflink/ldlinux/ldlinux.c32 .

install-data-local: pxelinux.0 chain.c32
	mkdir -p $(DESTDIR)/$(datadir)/warewulf/
	install -m 644 pxelinux.0 $(DESTDIR)/$(datadir)/warewulf/
	install -m 644 ldlinux.c32 $(DESTDIR)/$(datadir)/warewulf/
	install -m 644 chain.c32 $(DESTDIR)/$(datadir)/warewulf/
	install -m 644 libutil.c32 $(DESTDIR)/$(datadir)/warewulf/
	install -m 644 libcom32.c32 $(DESTDIR)/$(datadir)/warewulf/

uninstall-local:
	rm -rf $(DESTDIR)/$(datadir)/warewulf/pxelinux.0 $(DESTDIR)/$(datadir)/warewulf/chain.c32
	rm -rf $(DESTDIR)/$(datadir)/warewulf/ldlinux.c32 $(DESTDIR)/$(datadir)/warewulf/libutil.c32
	rm -rf $(DESTDIR)/$(datadir)/warewulf/libcom32.c32

clean-local:
	rm -rf _work pxelinux.0 ldlinux.c32 chain.c32 libutil.c32 libcom32.c32
