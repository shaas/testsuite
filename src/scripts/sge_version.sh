#!/bin/sh

sge_srcdir=$1

cat ${sge_srcdir}/libs/gdi/version.c | grep "const char GDI_VERSION\[] =" | awk -F\" '{print $2}' 2>/dev/null