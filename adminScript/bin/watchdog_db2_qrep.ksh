#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď� for Q-Replication
# ���s�d�l      : �ʏ�Ăяo���i�����Ȃ��j
# �Ǎ��t�@�C��  : ${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst
# �����t�@�C��  : ${G_SCR_LOG_HOME}/${SCR_NAME}.log
# �߂�l        : 0 �ȊO�ُ͈�I��
# �X�V����      : YYYY/MM/DD    �V�K�쐬
################################################################################
# �O���t�@�C���Ǎ��E�ϐ���`
SCR_HOME=$(dirname $0)

. ${SCR_HOME}/_common_profile.conf
. ${SCR_HOME}/${G_SCR_LIB}
. ${SCR_HOME}/${G_SCR_MW_CONF}
. ${SCR_HOME}/${G_SCR_MW_LIB}

# ���[�J���ϐ������l�Z�b�g
# SCR_HOME�O���[�o���l�֒u����������
if [[ "${SCR_HOME}" = "." ]]; then SCR_HOME=${G_SCR_HOME:=.}; fi

# �X�N���v�g���ʃ��[�J���ϐ���`�u���b�N�i��{�I�ɑS�ẴX�N���v�g�Œ�`���ׂ��ϐ��Q�j
SCR_NAME=$(basename $0 ${G_SCR_SFX})                        # �X�N���v�g���擾
HOSTNAME=$(hostname)                                        # �z�X�g���擾
MSGLIST=${G_SCR_ETC_HOME}/${G_SCR_MSG}                      # �X�N���v�g���b�Z�[�W��`�t�@�C����
MSGMODE=${G_MSGMODE}                                        # ���b�Z�[�W�o�̓��[�h
LOGDATE=$(date +%Y%m%d)                                     # �X�N���v�g���O�t�@�C�����Ƀ^�C���X�^���v���܂߂�ꍇ�g�p������t�B
LOGFILE=${G_SCR_LOG_HOME}/${SCR_NAME}.log                   # �X�N���v�g���O�t�@�C����
LOGGER_TAG=${SCR_NAME}                                      # syslog�o�͋L�^�p�^�O������
RC=0                                                        # ReturnCode Reset

# �X�N���v�g�Ǝ����[�J���ϐ���`�u���b�N�i�X�N���v�g���ɈقȂ��`�̕ϐ��Q�j
WATCH_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst            # �Ď��Ώۃ��X�g�t�@�C����
OBJECT_LIST=${G_SCR_ETC_HOME}/${G_SCR_MW_OBJECT}            # �~�h���E�F�A�I�u�W�F�N�g���X�g�t�@�C����
MW_NAME="QREP"
MW_NAME_MQM="MQM"
DB2_PROFILE=~/sqllib/db2profile
PASSWORD=
MQMUSR="mqm"        # MQ Manager User Default
MQMGRS=             # MQ Manager
MQLSNS=             # MQ Listner
MQCNLS=             # MQ Channel
REP_SVR=            # �L���v�`���[�T�[�o�[ or �A�v���C�T�[�o�[
rproc=
exclude_list=''
# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [ �f�[�^�x�[�X�� ]"
    echo "��P�����͔C�ӂł��B�w�肪�����ꍇ�͓o�^���X�g���`�F�b�N����܂��B"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# �����`�F�b�N
# ------------------------------------------------------------------------------
checkOptions() {
    case "$#" in
        0)  :
            ;;
        1)  REP_SVR="$1"
            ;;
        *)  showHelp
            ;;
    esac
}

# ------------------------------------------------------------------------------
# �X�N���v�g������
# ------------------------------------------------------------------------------
initializer() {
    getMessage "000001I";logWriter ${LOGFILE} "${message}"
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME}"
}

# ------------------------------------------------------------------------------
# Q Caputure Server Status�m�F
# ------------------------------------------------------------------------------
watchCAPStatus() {
    MW_NAME="QCAP"
    rproc=${G_QCAP_PROC:=asnqcap}
    
    # ��P�����w�肪�����ꍇ�̓z�X�g�����烌�v���P�[�V�����v���Z�X�ꗗ���擾����B
    if [[ "${REP_SVR}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVR="$_OBJ1"    # �L���v�`���[�T�[�o�[�ꗗ
        if [[ "${REP_SVR}" = "" ]]; then
            getMessage "999009I";logWriter ${LOGFILE} "Q-Rep Caputure Server �����݂��Ȃ��̂ŃX�L�b�v���܂��B"; return
        fi
    fi

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        getMessage "OPE001I";logWriter ${LOGFILE} "Q-Rep Caputure Server ${svr} �̊m�F${message}"

        # Rep Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"        # �C���X�^���X���[�U�[
        _schema="$_OBJ2"      # �X�L�[�}��
        MQMGRS="$_OBJ3"      # MQ Manager��
        
        # MQ �X�e�[�^�X�m�F
        watchMQStatus ${MQMGRS}
        
        # Qrep�v���Z�X�m�F
        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "Q-Rep Caputure Server ${svr} ${message}"
        else
            getMessage "SWC019I";logWriter ${LOGFILE} "Q-Rep Caputure Server ${svr} ${message}"
        fi

        # Qrep �A�v���P�[�V�����ڑ��m�F
        su - ${_user} -c "db2 connect to ${svr}" > /dev/null 2>&1 || return
        procs=$(su - ${_user} -c "db2 list applications" | grep -v grep | grep ${rproc} | wc -l | sed 's/ //g')
        #getMessage "999009I";logWriter ${LOGFILE} "�ڑ��A�v���P�[�V������=$procs"

        cat ${WATCH_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'${rproc}'" ) {print $4,$5}}'|while read limit_w limit_c
        do
            # 臒l�w�肪�����ꍇ��1�Ƃ݂Ȃ�
            if [[ "$limit_w" = "" ]]; then limit_w=1; fi
            if [[ "$limit_c" = "" ]]; then limit_c=1; fi
            
            if [[ ${procs} -lt $limit_c ]]; then
                getMessage "WD0042C";logWriter ${LOGFILE} "Q-Rep�v���Z�X ${rproc} �̐ڑ�����臒l $limit_c �������܂����BCOUNT=${procs}"
            elif [[ ${procs} -lt ${limit_w} ]]; then
                getMessage "WD0042W";logWriter ${LOGFILE} "Q-Rep�v���Z�X ${rproc} �̐ڑ�����臒l $limit_w �������܂����BCOUNT=${procs}"
            else
                getMessage "WD0042I";logWriter ${LOGFILE} "Q-Rep�v���Z�X ${rproc} �̐ڑ����͐���l�ł��B COUNT=${procs}"
            fi
        done
        
        # �T�u�X�N���v�V�����X�e�[�^�X�m�F
        #getMessage "999009I";logWriter ${LOGFILE} "�񊈓��T�u�X�N���v�V�����m�F���J�n���܂��B"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QCAP_TBL_SUBS:="IBMQREP_SUBS"}.tmp"
        #su - ${_user} -c "db2 -x \"select count(*) from ${_schema}.${G_QCAP_TBL_SUBS} where state != 'A'\""| sed 's/ //g' > ${TMP_LIST}
        #unact=$(cat ${TMP_LIST})
        #if [[ ${unact} -ne 0 ]]; then
        #    getMessage "999009W";logWriter ${LOGFILE} "�񊈓���Ԃ̃T�u�X�N���v�V������ ${unact}������܂��B"
        #    RC=3
        #fi

        # ��O�\�����m�F
        #getMessage "999009I";logWriter ${LOGFILE} "��O�\�����m�F���J�n���܂��B"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QAPP_TBL_EXCEPT:="IBMQREP_EXCEPTIONS"}.tmp"
        #su - ${_user} -c "db2 select SUBNAME, REASON, IS_APPLIED from ${_schema}.${G_QAPP_TBL_EXCEPT}" > ${TMP_LIST}
        #awk ' BEGIN { NUM=0 } $1~"^SUB-" { NUM = NUM + 1 } END { print NUM }' ${TMP_LIST} | read except_val
        #[[ ${except_val} -ne 0 ]] && {
        #    getMessage "999009W";logWriter ${LOGFILE} "��O�\�� ${except_val} ���̏������L�^����Ă��܂��B"
        #}

        # MQ �I�u�W�F�N�g(Local Queue)�擾
        #XXXXXgetObject ${HOSTNAME} ${MW_NAME_MQM}_OBJ ${MQMGRS}
        #XXXXXlocal_q="$_OBJ3"

        # ��M�L���[�ғ��m�F ###
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_recvq.tmp"
        #su - ${_user} -c "db2 select STATE from ${_schema}.IBMQREP_RECVQUEUES" | awk 'BEGIN { NO=0 } {if( $1 == "STATE" ) NO=NR+2 ; if( NR == NO ) { print $1 };}' > ${TMP_LIST}
        #recvq=$(cat ${TMP_LIST})
        #if [[ "${recvq}" != "A" ]] ; then
        #    # FNC_COMM_LOGGING "QREP" "CRIT" "��M�L���[ "${local_q}" ���A�N�e�B�u��Ԃł͂���܂���B"
        #    getMessage "999009W";logWriter ${LOGFILE} "��M�L���[ ${local_q} ���A�N�e�B�u��Ԃł͂���܂���B"
        #fi

    done
}

# ------------------------------------------------------------------------------
# Q Apply Server Status�m�F
# ------------------------------------------------------------------------------
watchAPPStatus() {
    MW_NAME="QAPP"
    rproc="${G_QAPP_PROC:=asnqapp}"       # �v���Z�X��

    # ��P�����w�肪�����ꍇ�̓z�X�g�����烌�v���P�[�V�����v���Z�X�ꗗ���擾����B
    if [[ "${REP_SVR}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVR=$_OBJ1     # Q Rep�v���Z�X�ꗗ �擾
        if [[ "${REP_SVR}" = "" ]]; then
            getMessage "999009I";logWriter ${LOGFILE} "Q-Rep Apply Server �̎w�肪���݂��Ȃ��̂ŃX�L�b�v���܂��B"; return
        fi
    fi    

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        getMessage "OPE001I";logWriter ${LOGFILE} "Q-Rep Apply Server ${svr} �̊m�F${message}"
        # Rep Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"         # �C���X�^���X���[�U�[
        _schema="$_OBJ2"      # �X�L�[�}��
        MQMGRS="$_OBJ3"      # MQ Manager��
        
        # MQ �X�e�[�^�X�m�F
        watchMQStatus ${MQMGRS}

        # Qrep�v���Z�X�m�F
        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "Q-Rep Apply Server ${svr} ${message}"
        else
            getMessage "SWC019I";logWriter ${LOGFILE} "Q-Rep Apply Server ${svr} ${message}"
        fi

        # Qrep �A�v���P�[�V�����ڑ��m�F
        su - ${_user} -c "db2 connect to ${svr}" > /dev/null 2>&1 || return
        procs=$(su - ${_user} -c "db2 list applications" | grep -v grep | grep ${rproc} | wc -l | sed "s/ //g")
        #getMessage "999009I";logWriter ${LOGFILE} "�ڑ��A�v���P�[�V������=$procs"

        cat ${WATCH_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'${rproc}'" ) {print $4,$5}}'|while read limit_w limit_c
        do
            # 臒l�w�肪�����ꍇ��1�Ƃ݂Ȃ�
            if [[ "$limit_w" = "" ]]; then limit_w=1; fi
            if [[ "$limit_c" = "" ]]; then limit_c=1; fi
            
            if [[ ${procs} -lt $limit_c ]]; then
                getMessage "WD0042C";logWriter ${LOGFILE} "Q-rep�v���Z�X ${rproc} �̐ڑ�����臒l $limit_c �������܂����BCOUNT=${procs}"
            elif [[ ${procs} -lt ${limit_w} ]]; then
                getMessage "WD0042W";logWriter ${LOGFILE} "Q-rep�v���Z�X ${rproc} �̐ڑ�����臒l $limit_w �������܂����BCOUNT=${procs}"
            else
                getMessage "WD0042I";logWriter ${LOGFILE} "Q-rep�v���Z�X ${rproc} �̐ڑ����͐���l�ł��B COUNT=${procs}"
            fi
        done
        
        # �T�u�X�N���v�V�����X�e�[�^�X�m�F
        #getMessage "999009I";logWriter ${LOGFILE} "�񊈓��T�u�X�N���v�V�����m�F���J�n���܂��B"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QAPP_TBL_TARGET:=IBMQREP_TARGETS}.tmp"
        #su - ${_user} -c "db2 -x \"select count(*) from ${_schema}.${G_QAPP_TBL_TARGET} where state != 'A'\""| sed 's/ //g' > ${TMP_LIST}
        #unact=$(cat ${TMP_LIST})
        #if [[ ${unact} -ne 0 ]]; then
        #    getMessage "999009W";logWriter ${LOGFILE} "�񊈓���Ԃ̃T�u�X�N���v�V������ ${unact}������܂��B"
        #    RC=3
        #fi

        # ��O�\�����m�F
        #getMessage "999009I";logWriter ${LOGFILE} "��O�\�����m�F���J�n���܂��B"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QAPP_TBL_EXCEPT:=IBMQREP_EXCEPTIONS}.tmp"
        #su - ${_user} -c "db2 select SUBNAME, REASON, IS_APPLIED from ${_schema}.${G_QAPP_TBL_EXCEPT}" > ${TMP_LIST}
        #awk ' BEGIN { NUM=0 } $1~"^SUB-" { NUM = NUM + 1 } END { print NUM }' ${TMP_LIST} | read except_val
        #[[ ${except_val} -ne 0 ]] && {
        #    getMessage "999009W";logWriter ${LOGFILE} "��O�\�� ${except_val} ���̏������L�^����Ă��܂��B"
        #}

        # MQ �I�u�W�F�N�g(Local Queue)�擾
        #XXXXXgetObject ${HOSTNAME} ${MW_NAME_MQM}_OBJ ${MQMGRS}
        #XXXXXlocal_q="$_OBJS3"

        # ��M�L���[�ғ��m�F ###
        TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_recvq.tmp"
        su - ${_user} -c "db2 select STATE from ${_schema}.${G_QAPP_TBL_RECVQS:=IBMQREP_RECVQUEUES}" | awk 'BEGIN { NO=0 } {if( $1 == "STATE" ) NO=NR+2 ; if( NR == NO ) { print $1 };}' > ${TMP_LIST}
        recvq=$(cat ${TMP_LIST})
        if [[ "${recvq}" != "A" ]] ; then
            getMessage "999009W";logWriter ${LOGFILE} "��M�L���[ ${local_q} ���A�N�e�B�u��Ԃł͂���܂���B"
        fi

    done
}

# ------------------------------------------------------------------------------
# �I������
# ------------------------------------------------------------------------------
finalizer() {
    getMessage "000099I";logWriter ${LOGFILE} "${message} ${SCR_NAME} RC:$RC"
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

watchCAPStatus
watchAPPStatus

finalizer
exit 0
