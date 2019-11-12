#!/bin/ksh

### ENVIRONMENT ###
. /home/dsansyot/.profile
DIR=/home/dsansyot/asnapl
LST=${DIR}/start_apl.lst
DT=`date +%Y%m%d%H%M`
LOG="/home/dsansyot/asnapl/start_apl_${DT}.log"
CNT=0
STS=0

### START MESSAGE ###
echo "[`date +%H:%M:%S`] �e�X�g�n���v���P�[�V����(Apply)���J�n���܂�" | tee -a ${LOG}

### APPLY ###
for APP in `cat ${LST} | grep -v ^# | grep -v ^$` ; do
	### APPLY START ###
	asnapply \
	 apply_qual=${APP} \
	 control_server=dsansyot \
	 apply_path=/home/dsansyot/asnapl \
	 logreuse=n \
	 loadxit=y \
	 sleep=n \
	| tee -a ${LOG}

	### RESULT CHECK ###
	STS=$?
	if [[ ${STS} -ne 0 ]] ; then
		CNT=`expr ${CNT} + ${STS}`
	fi

	### MANUAL STOP ###
	if [[ -f ${DIR}/${APP}.stop ]] ; then
		echo "[`date +%H:%M:%S`] ���v���P�[�V����������r����~���܂�" | tee -a ${LOG}
		exit 0
	fi
done

### TABLE MAINTENANCE ###
sleep 60

db2 connect to dcist user dcist using DCIST#IZU > /dev/null
echo "REPLICATION CAPTURE CTRL TBLSPACE INFO :" | tee -a ${LOG}
db2 list tablespaces show detail | grep -p REP | egrep "���O|���v|�g�p����" \
 | tee -a ${LOG}
db2 terminate > /dev/null

db2 connect to dsansyot > /dev/null
echo "REPLICATION APPLY CTRL TBLSPACE INFO :" | tee -a ${LOG}
db2 list tablespaces show detail | grep -p REP | egrep "���O|���v|�g�p����" \
 | tee -a ${LOG}

#echo "IBMSNAP_APPLYTRACE 7���ȏ�o�ߌ��� :" | tee -a ${LOG}
#db2 "select count(*) from asn.ibmsnap_applytrace \
# where trace_time < (current timestamp - 7 day)" | tee -a ${LOG}
#echo "IBMSNAP_APPLYTRAIL 7���ȏ�o�ߌ��� :" | tee -a ${LOG}
#db2 "select count(*) from asn.ibmsnap_applytrail \
# where endtime < (current timestamp - 7 day)" | tee -a ${LOG}

db2 "delete from asn.ibmsnap_applytrace \
 where trace_time < (current timestamp - 7 day)" | tee -a ${LOG}
db2 "delete from asn.ibmsnap_applytrail \
 where endtime < (current timestamp - 7 day)" | tee -a ${LOG}

echo "IBMSNAP_APPLYTRACE �S���� :" | tee -a ${LOG}
db2 "select count(*) from asn.ibmsnap_applytrace" | tee -a ${LOG}
echo "IBMSNAP_APPLYTRAIL �S���� :" | tee -a ${LOG}
db2 "select count(*) from asn.ibmsnap_applytrail" | tee -a ${LOG}

db2 terminate > /dev/null

### END MESSAGE ###
if [[ ${CNT} -ne 0 ]] ; then
	echo "[`date +%H:%M:%S`] �e�X�g�n���v���P�[�V����(Apply)���ُ�I�����܂���" | tee -a ${LOG}
	exit 1
else
	echo "[`date +%H:%M:%S`] �e�X�g�n���v���P�[�V����(Apply)������I�����܂���" | tee -a ${LOG}
fi

exit 0
