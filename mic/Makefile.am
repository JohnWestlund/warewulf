SUBDIRS = lib libexec initramfs

MAINTAINERCLEANFILES = Makefile.in aclocal.m4 configure compile config.* ltmain.sh install-sh missing stamp-h1
DISTCLEANFILES = 
CLEANFILES = 
EXTRA_DIST = AUTHORS ChangeLog COPYING LICENSE LICENSE.Intel TODO warewulf-mic.spec

# Fix for make distcheck
DISTCHECK_CONFIGURE_FLAGS = --with-perllibdir=$$dc_install_base/perllibs
