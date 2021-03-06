AC_PREREQ(2.59)
AC_INIT([warewulf-monitor],[0.0.1],[warewulf-devel@lbl.gov])
AC_CONFIG_SRCDIR([.])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([.])

if test -z "$prefix" -o "$prefix" = "NONE" ; then
  prefix=${ac_default_prefix}
fi
AC_SUBST(PREFIX, $prefix)

AC_PROG_INSTALL
AM_INIT_AUTOMAKE
AC_PROG_LIBTOOL
AC_PROG_CC

AC_PATH_PROG(PERLBIN, perl)
if test -z "$PERLBIN"; then
   AC_MSG_ERROR([perl not found])
fi
AC_SUBST(PERLBIN)

dnl# Add default flags
CFLAGS="-std=gnu99 $CFLAGS"

dnl# Define UNUSED macro if possible
AC_MSG_CHECKING([for __attribute__ ((unused))])
AC_COMPILE_IFELSE(
   [AC_LANG_PROGRAM(
       [[
void foo(int x __attribute__ ((unused))) {}
       ]],
       [[
       ]])],
   [have_attribute_unused="yes"],
   [have_attribute_unused="no"])
AC_MSG_RESULT([${have_attribute_unused}])

if test "x${have_attribute_unused}" = "xyes" ; then
   AC_DEFINE([UNUSED], [__attribute__ ((unused))], [Macro declaring a function argument to be unused.])
else
   AC_DEFINE([UNUSED], [], [__attribute__ ((unused)) is not supported.])
fi

dnl#
dnl### LIBRARY CHECKS
dnl#

jsoncfound="0";
# Check for 0.10
echo "Checking for json-c 0.10";
if test "x$jsoncfound" = "x0"; then
    AC_CHECK_LIB(json, json_object_get,[LDFLAGS="-ljson $LDFLAGS" jsoncfound="1"], [])
fi

if test "x$jsoncfound" = "x0"; then
    echo "Checking for json-c 0.11";
    AC_CHECK_LIB(json-c, json_object_get,[LDFLAGS="-ljson-c $LDFLAGS"], [
    echo "ERROR:  You need libjson to build Warewulf Moniter module.";
    echo "        Verify that you have libjson.a or libjson.so installed";
    echo "        If it is in a different directory, try using";
    echo "        the LDFLAGS to set its proper path.";
                  AC_MSG_ERROR([Fatal:  libjson not found.])])
fi

sqlitefound="0";
# Check for sqlite 3.7
if test "x$sqlitefound" = "x0"; then
    AC_CHECK_LIB(sqlite3, sqlite3Init, [LDFLAGS="-lsqlite3 $LDFLAGS" sqlitefound="1"], [])
fi

# Check For sqlite 3.3.6
if test "x$sqlitefound" = "x0"; then
    AC_CHECK_LIB(sqlite3, sqlite3_initialize,[LDFLAGS="-lsqlite3 $LDFLAGS"], [
    echo "ERROR:  You need libsqlite3 to build Warewulf Moniter module.";
    echo "        Verify that you have libsqlite3.a or libsqlite3.so installed";
    echo "        If it is in a different directory, try using";
    echo "        the LDFLAGS to set its proper path.";
                  AC_MSG_ERROR([Fatal:  libsqlite3 not found.])])
fi

AC_MSG_CHECKING([for Perl vendor lib path])
eval `perl -V:installvendorlib`
PERL_VENDORLIB=$installvendorlib

AC_ARG_WITH(perllibdir, [  --with-perllibdir=path  Manually specify where the perl modules should go], [
if test -n "$withval" -a "x$withval" != "xno" ; then
   PERL_VENDORLIB=$withval
fi
])
AC_MSG_RESULT($PERL_VENDORLIB)
AC_SUBST(PERL_VENDORLIB)

AC_SUBST(PERLBIN)

dnl Make it so we can do @[SOMEVAR]@ in a file and
dnl   have it replaced with the configured path for
dnl   any of the main variables
dnl
dnl We do it through an eval call, as otherwise the
dnl   the variable is something like:
dnl       ${prefix}/var
dnl   and ${prefix} was never expanded.
AS_IF([test -n $localstatedir], [
    eval $(echo dir=$localstatedir)
    AC_SUBST(LOCALSTATEDIR, $dir)
])

dnl# Debug Build?
AC_ARG_ENABLE(debug,
    AS_HELP_STRING([--enable-debug],[Enable debug code. NOTE: Causes both collector/aggregator to run in forground.]),
    [
    AC_DEFINE(WWDEBUG, 1, [Build Debug Code])
    ],[])

dnl# Try to get SVN revision
SVNVERSION=`svnversion -c | sed 's/^.*://g' 2>/dev/null || echo 0000`
if test "$SVNVERSION" = "0000" ; then
    SVNVERSION=`svnversion 2>/dev/null || echo 0000`
fi
AC_SUBST(SVNVERSION)

AC_CONFIG_FILES([
   Makefile
   warewulf-monitor.spec
   src/Makefile
   src/globals.h
   bin/Makefile
   etc/Makefile
   etc/collector
   lib/Makefile
   lib/Warewulf/Makefile
])
AC_OUTPUT
