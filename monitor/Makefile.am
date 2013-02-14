SUBDIRS = lib bin src etc

MAINTAINERCLEANFILES = Makefile.in aclocal.m4 configure compile config.* ltmain.sh depcomp install-sh missing stamp-*
DISTCLEANFILES = 
CLEANFILES = *.m4
EXTRA_DIST = warewulf-monitor.spec

# Fix for make distcheck
DISTCHECK_CONFIGURE_FLAGS = --with-perllibdir=$$dc_install_base/perllibs
