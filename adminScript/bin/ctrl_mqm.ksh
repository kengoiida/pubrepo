#!/bin/ksh
################################################################################
# �@�\�T�v      : MQ Manager�N��/��~/�m�F
# ���s�d�l      : �����w��𔺂����ʏ�Ăяo��
# �Ǎ��t�@�C��  : ���ʊO����`�t�@�C��
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
MW_NAME="MQM"
MQMUSR="mqm"        # MQ Manager User Default
MQMGRS=             # MQ Manager
MQLSNP=             # MQ Listner Port No
MQCHLS=             # MQ Channel
MQQUES=             # MQ Queue

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | restart | status] [MQ�}�l�[�W���[��]" 
    echo "��P�����͕K�{"
    echo "��Q������MQ�}�l�[�W���[�����w�肵�ĉ�����(�C��) �B�w�肪�����ꍇ�͓o�^���X�g���Q�Ƃ��܂��B"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# �����`�F�b�N
# ------------------------------------------------------------------------------
checkOptions() {
    option="$1"

    case "$#" in
        1)  :
            ;;
        2)  MQMGRS="$2"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} ${MQMGRS}"

    getObject ${HOSTNAME} ${MW_NAME}
    if [[ "$_OBJ2" != "" ]]; then MQMUSR="$_OBJ2"; fi
    # ��Q�����w�肪�����ꍇ�͓o�^���X�g����MQ Manager �ꗗ���擾����B
    if [[ "${MQMGRS}" = "" ]]; then
        if [[ "$_OBJ1" != "" ]]; then
            MQMGRS="$_OBJ1"
        else
            # �o�^���X�g�ł��m�F�o���Ȃ��ꍇmqs.ini����擾����B
            getMQMInfo "$_OBJ3"
        fi
    fi    
}

# ------------------------------------------------------------------------------
# �N��
# ------------------------------------------------------------------------------
doStart() {
(( ${DBG_FLG} )) && set -x

    # MQ Object �N��
    for mqmgr in $(echo "${MQMGRS}" | sed "s/,/ /g")
    do
        # MQ Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}

        # MQ Manager Status �擾
        getMQMStatus ${mqmgr}
        if [[ "${mqm_status}" != "" ]]; then
            getMessage "SWC009W";logWriter ${LOGFILE} "${mqmgr} ${message}"
            continue
        fi

        su - ${MQMUSR} -c "strmqm ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        if [[ $RC != 0 ]]; then
            getMessage "SWC002C";logWriter ${LOGFILE} "${mqmgr} ${message} RC=$RC"
            exit 99
        fi

        # Command Server �N��
        #su - ${MQMUSR} -c "strmqcsv ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        #if [[ $RC != 0 ]]; then
        #    getMessage "SWC002C";logWriter ${LOGFILE} "Command Server ${message} RC=$RC"
        #    exit 99
        #fi

        getMessage "SWC002I";logWriter ${LOGFILE} "${mqmgr} ${message}"

    done

}

# ------------------------------------------------------------------------------
# ��~
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x

    MQ_EXEC_FILE=""

    # MQ Object ��~
    for mqmgr in $(echo "${MQMGRS}" | sed "s/,/ /g")
    do
        # MQ Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}

        # MQ Manager Status �m�F
        getMQMStatus ${mqmgr}
        if [[ "${MQM_STATUS}" = "" ]]; then
            getMessage "SWC059W";logWriter ${LOGFILE} "$mqmgr ${message}"
            continue
        fi

        # Command Server ��~
        #su - ${MQMUSR} -c "endmqcsv -i ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        #getMessage "SWC052I";logWriter ${LOGFILE} "Command Server ${message} RC=$RC"

        # MQ Manager ��~
        su - ${MQMUSR} -c "endmqm -i ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        if [[ $RC != 0 ]]; then
            getMessage "SWC052C";logWriter ${LOGFILE} "${mqmgr} ${message} RC=$RC"; return
        fi
        getMessage "SWC052I";logWriter ${LOGFILE} "${mqmgr} ${message}"
    done
}

# ------------------------------------------------------------------------------
# �ċN��
# ------------------------------------------------------------------------------
doRestart() {
    :
}

# ------------------------------------------------------------------------------
# MQ Object Status �擾
# ------------------------------------------------------------------------------
getStatus() {
(( ${DBG_FLG} )) && set -x

    # MQ Object Status �擾
    for mqmgr in $(echo "${MQMGRS}" | sed "s/,/ /g")
    do
        # MQ Manager Status �擾
        getMQMStatus ${mqmgr}
        if [[ "${MQM_STATUS}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "MQ Manager ${mqmgr} ${message}"
        else
            getMessage "WD0041I";logWriter ${LOGFILE} "MQ Manager ${mqmgr} ${message}"
        fi
    done
}

# ------------------------------------------------------------------------------
# �X�N���v�g�I������
# ------------------------------------------------------------------------------
finalizer() {
    getMessage "000099I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} RC=${RC}"
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

case "${option}" in
    start)
        doStart
        ;;
    stop)
        doStop
        ;;
    restart)
        doRestart
        ;;
    status)
        getStatus
        ;;
    *)
        showHelp
        ;;
esac

finalizer

exit 0

