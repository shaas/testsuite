#!/bin/sh -x

###############################################################################
# Copyright:    2006 by Sun Microsystems, Inc. All Rights Reserved.
# Purpose:      Installs hedeby
# Usage:        hedeby_install.sh -h "host1,host2,..."
# File:         %W% %E%
# Usage:        %M%
# Author:       Ovid Jacob
# Source file:  .hedeby_installrc
###############################################################################


usage(){

#
# print out usage
#

        echo "Usage: $0 -h "host1,host2,..." \n"

# print out man page - like description from the end of this file

        sed -n 's/^#M#//p' $0
exit 1

}

setup_cli(){

# Check for command line input

	echo "Command:  $PROG $*"
        for i in $*
        do
        	case $1 in
    		-h)  HOSTS=$2
                export HOSTS
                shift 2
                ;;
            	-*)  usage
                ;;
            	esac
        done


# remove ","s from the strings so rsh can process easier
	s_hosts=`echo $HOSTS | sed 's/,/ /g'`; export s_hosts
	HOSTS=$s_hosts

	echo "Final hosts are $HOSTS \n"

# check that the these important vars are set in .hedeby_installrc:
# HAITHABU_HOME
# GRM_DIST
# JAVA_HOME
# JAVA_HOME_32

	if [ "X${HAITHABU_HOME}" = "X" ]
        then
        echo "FAILED : HAITHABU_HOME not set in .hedeby_installrc " | tee  -a ${LOGFILE}
        return 1
        fi
	
	if [ "X${GRM_DIST}" = "X" ]
        then
        echo "FAILED : GRM_DIST not set in .hedeby_installrc " | tee  -a ${LOGFILE}
        return 1
        fi

	if [ "X${JAVA_HOME}" = "X" ]
        then
        echo "FAILED : JAVA_HOME not set in .hedeby_installrc " | tee  -a ${
LOGFILE}
        return 1
        fi

	if [ "X${JAVA_HOME_32}" = "X" ]
        then
        echo "FAILED : HAITHABU_HOME not set in .hedeby_installrc " | tee  -a ${
LOGFILE}
        return 1
        fi


return 0

}


get_haitabu_jar_tar () {

# - rm old hedeby.tar
  echo "rm old copy of $GRM_DIST/hedeby.tar \n"
  cd $GRM_DIST; rm -f $GRM_DIST/hedeby.tar

# - copy, gunzip , untar hedeby.tar.gz
  echo "copying $HAITHABU_HOME/dist/hedeby.tar.gz to  $GRM_DIST \n"
  cp -f $HAITHABU_HOME/dist/hedeby.tar.gz $GRM_DIST

# - copy hedeby.jar
  echo "copying $HAITHABU_HOME/dist/hedeby.jar to  $GRM_DIST/dist \n"
  cp -f $HAITHABU_HOME/dist/hedeby.jar $GRM_DIST/dist

  echo "gunzip'ing, untar'ing to  $GRM_DIST/hedeby.tar.gz \n"
  cd $GRM_DIST; gunzip -q hedeby.tar.gz; tar xf hedeby.tar 

# - copy  $HAITHABU_HOME/hedeby.class to  $GRM_DIST
  echo "copying $HAITHABU_HOME/hedeby.class to  $GRM_DIST \n"
  cp $HAITHABU_HOME/hedeby.class $GRM_DIST

# - copy the jar files in  $GRM_DIST/lib/lib
  echo "copy the jar files in $GRM_DIST/lib/lib \n"
  cd $GRM_DIST; cp lib/*jar lib/lib/ 
}

get_inst_grm () {

# - copy $HAITHABU_HOME/util/inst_grm.sh to  $GRM_DIST
  echo "copying $HAITHABU_HOME/util/inst_grm.sh to  $GRM_DIST \n"
  cp $HAITHABU_HOME/util/inst_grm.sh $GRM_DIST

}

get_host_id () {

#   - Get my id with ./inst_grm.sh -id. Pass the 32-bit JVM
#     via 'env' command'
 
  echo "Get the local id with inst_grm.sh -id \n"
  MY_ID=`env JAVA_HOME=$JAVA_HOME_32 inst_grm.sh -id `

#   - Add this id to the statefile.txt template file
 
  echo "sed statefile.txt, put in my local id \n" 
  rm -f install.state
  sed  "s/_id_/$MY_ID/g" statefile.txt > install.state

}

get_install_sdk () {

# get install_sdk package
   echo "Copying install_sdk from /array2"

   cd /var/tmp/install_sdk; cp -f /array2/install_sdk.tar.gz .  
   gunzip -qf install_sdk.tar.gz; tar xf install_sdk.tar   

}


run_installer_auto () {

  cd $GRM_DIST 
   sleep 2
#        ( run
#          to create install.state if it is not created; otherwise, skip this step)
#       echo "running $JAVA_HOME_32/bin/java -cp ./lib/jgdi.jar:./lib/juti.jar:./hedeby.jar:. hedeby -saveState $GRM_DIST/install.state \n"
#         $JAVA_HOME_32/bin/java -cp ./lib/jgdi.jar:./lib/juti.jar:./hedeby.jar:. hedeby -saveState $GRM_DIST/install.state

#        - run auto installer
         echo "running  $JAVA_HOME_32/bin/java -cp ./lib/lib/jgdi.jar:./lib/lib/juti.jar:./lib/hedeby.jar:. hedeby -noconsole -nodisplay -state $GRM_DIST/install.state \n"
        java -cp ./lib/lib/jgdi.jar:./lib/lib/juti.jar:./lib/hedeby.jar:. hedeby -noconsole -nodisplay  -state $GRM_DIST/install.state

}

run_svcgrm () {

#- run svcgrm to stop/start hedeby

  echo "stopping svcgrm \n"
  cd $GRM_DIST/bin; ./svcgrm stop

  sleep 2
  # kill the ChildStartupService explictly for now 
  $JAVA_HOME/bin/jps -l
  CSS_PID=`$JAVA_HOME/bin/jps -l |grep ChildStartupService |awk '{print $1}'`
  echo "CSS_PID is $CSS_PID \n"
  kill -9 $CSS_PID

  echo "starting svcgrm \n"
  cd $GRM_DIST/bin; ./svcgrm start

}

run_gstat () {

#        - run gstat -s <system> ss

	HOST=$1
   sleep 3
   echo "show state with gconf \n"
   gstat -s $HOST ss
}

register_resources () {

# Remove/Add resources dt218-67, gridengine2, dt218-33
# Add then properties hardwareCpuArchitecture, operatingSystemName,
# hardwareCpuCount, hardwareCpuFrequency, operatingSystemVendor,
# resourceIPAddress

HOST1=$1
HOST2=$2 
HOST3=$3

echo "hosts are $HOST1 $HOST2 $HOST3 .... \n"
echo "host1 is $HOST1 .... \n"
echo "host2 is $HOST2 .... \n"
echo "host3 is $HOST3 .... \n"

IP1=`ypcat hosts |grep $HOST1 |awk  '{print $1}'`
IP2=`ypcat hosts |grep $HOST2 |awk  '{print $1}'`
IP2=`echo $IP2 |awk '{print $1}'`
IP3=`ypcat hosts |grep $HOST3 |awk  '{print $1}'`
IP3=`echo $IP3 |awk '{print $1}'`

echo "IPs are $IP1 $IP2 $IP3 ... \n"
echo "IP1 is $IP1 ... \n"
echo "IP2 is $IP2 ... \n"
echo "IP3 is $IP3 ... \n"

echo " removing resource $HOST1 \n"
$GRM_DIST/bin/gconf rr $HOST1

echo " adding resource $HOST1 \n"
$GRM_DIST/bin/gconf ar -t host resourceHostname=$HOST1 hardwareCpuArchitecture=SPARC operatingSystemName=Solaris hardwareCpuCount=2 hardwareCpuFrequency=1280MHz operatingSystemVendor=SunMicrosystems resourceIPAddress=$IP1


echo " removing resource $HOST2 \n"
$GRM_DIST/bin/gconf rr $HOST2

echo " adding resource $HOST2 \n"
$GRM_DIST/bin/gconf ar -t host resourceHostname=$HOST2 hardwareCpuArchitecture=AMD operatingSystemName=Solaris hardwareCpuCount=4 hardwareCpuFrequency=1503MHzi operatingSystemVendor=SunMicrosystems resourceIPAddress=$IP2

if [ "X${HOST3}" != "X" ]
then
	echo " removing resource $HOST3 \n"	
	$GRM_DIST/bin/gconf rr $HOST3

	echo " adding resource $HOST3 \n"
	$GRM_DIST/bin/gconf ar -t host resourceHostname=$HOST3 hardwareCpuArchitecture=SPARC operatingSystemName=Solaris hardwareCpuCount=4 hardwareCpuFrequency=450MHz operatingSystemVendor=SunMicrosystems resourceIPAddress=$IP3
fi


echo " show all the resources \n"
$GRM_DIST/bin/gconf srs

echo "show resource $HOST1 \n"
$GRM_DIST/bin/gconf sr $HOST1

echo "show resource $HOST2 \n"
$GRM_DIST/bin/gconf sr $HOST2

if [ "X${HOST3}" != "X" ]
then
	echo "show resource $HOST3 \n"
	$GRM_DIST/bin/gconf sr $HOST3
fi

}

#
#       MAIN
#
########################################
# Set the environment.
########################################

# Set -u
#       if [ $DEBUG -gt 0 ]
#       then set -x
#       fi

PROG=`basename $0`; export PROG
HOSTNAME=`uname -n`; export HOSTNAME
CURDIR=`pwd`; export CURDIR
LOGDIR=${LOGDIR:-/var/tmp/${PROG}}; export LOGDIR
SOURCEFILE=$CURDIR/.${PROG}rc

	echo "$SOURCEFILE"

# source in the .hedeby_installrc if it exists

        if [  -f $SOURCEFILE ]
        then
        . ${SOURCEFILE}
        fi

	setup_cli $*

        if [ $? -ne 0  ]
        then
        echo "setup_cli: FAILED"  | tee  -a ${LOGFILE}

	exit 1
        fi

	get_haitabu_jar_tar 

	if [ $? -ne 0  ]
        then
        echo "get_haitabu_jar_tar: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi


	get_inst_grm 

	if [ $? -ne 0  ]
        then
        echo "get_inst_grm: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi

	get_host_id 

	if [ $? -ne 0  ]
        then
        echo "get_host_id: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi

	get_install_sdk 

        if [ $? -ne 0  ]
        then
        echo "get_install_sdk: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi

	run_installer_auto 

        if [ $? -ne 0  ]
        then
        echo "run_installer_auto: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi

	run_svcgrm 

        if [ $? -ne 0  ]
        then
        echo "run_svcgrm: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi

	run_gstat $HOSTNAME

        if [ $? -ne 0  ]
        then
        echo "run_svcgrm: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi

	echo "HOSTS are $HOSTS \n"

	register_resources $HOSTS
	
	if [ $? -ne 0  ]
        then
        echo "register_resources: FAILED"  | tee  -a ${LOGFILE}

        exit 1
        fi


exit 0

###############################################################################
# MAN
###############################################################################
#M#NAME
#M#    hedeby_install.sh  
#M#
#M#SYNOPSIS
#M#     hedeby_install.sh [-h]
#M#
#M#DESCRIPTION
#M#    Install hedeby :  hedeby_install
#M#    Make necessary changes in .hedeby_installrc or input from command line
#M#
#M#    $HAITHABU_HOME - hedeby installed home
#M#    $GRM_DIST - hedeby distribution home
#M#    $JAVA_HOME - Java home
#M#    $JAVA_HOME_32 - Old Java home
#M#    $LOGDIR - log directory
#M#
#M#OPTIONS
#M#    [-h]
#M#     Print the man page.
#M#EXAMPLES
#M#    To print this man page:
#M#     >  hedeby_install.sh -h
#M#
#M#
#M#RETURN VALUES
#M#    0  All went well.
#M#   >1  An error occured (a helpful error message will be printed).
#M#
#M#SEE ALSO
#M#    hedeby_install.sh
#M#
#M#AUTHOR
#M#    Ovid Jacob
#M#
###############################################################################
# END
###############################################################################


