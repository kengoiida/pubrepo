#!/bin/ksh
################################################################################
# �@�\�T�v      : MQ Channel�N��/��~/�m�F
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
    echo "Usage: $(basename $0) [start | stop | restart | status] [ MQ�}�l�[�W���[�� | �L�[���[�h] [ MQ�`���l���� ]" 
    echo "��P�����͕K�{"
    echo "��Q�����͔C�ӂł��B�Ώ�MQ�}�l�[�W���[���܂��̓L�[���[�h���w�肵�ĉ������B"
    echo "                    �w�肪�����ꍇ�̓L�[���[�h�Ƃ��ăz�X�g�����w�肳�ꂽ�Ƃ݂Ȃ���A"
    echo "                    �SMQ�}�l�[�W���[���ΏۂƂȂ�܂��B"
    echo "��R�����͔C�ӂł��B�Ώ�MQ�`���l�������w�肵�ĉ������B"
    echo "                    �w�肪�����ꍇ�͑Ώ�MQ�}�l�[�W���̑S�Z���_�[�`���l�����ΏۂƂȂ�܂��B"
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
            unset MQCHLS
            ;;
        3)  MQMGRS="$2"
            MQCHLS="$3"
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
    if [[ "$_OBJ1" != "" ]]; then MQMUSR="$_OBJ1"; fi
    # ��Q�����w�肪�����ꍇ�̓z�X�g������MQ Manager �ꗗ���擾����B
    if [[ "${MQMGRS}" = "" ]]; then
        if [[ "$_OBJ2" != "" ]]; then
            MQMGRS="$_OBJ2"
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
    for mqmgr in ${MQMGRS}
    do
        # MQ Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}
        MQCHLS="${MQCHLS:-$_OBJ2}"    # �����w�肪�����ꍇ�̓��X�g�t�@�C���̒l��ݒ�

        # MQ Manager Status �擾
        getMQMStatus ${mqmgr}
        # MQ Manager �N����Ԋm�F
        if [[ "${mqm_status}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "$mqmgr ${message} Skipping ..."
            MQCHLS=""
            continue
        fi

        # MQ Channel �ڑ�
        for mqchl in ${MQCHLS}
        do
            getMessage "SWC001I";logWriter ${LOGFILE} "MQ Channel ${mqchl} ${message}"
            echo "start channel(${mqchl})" | \
            su - ${MQMUSR} -c "runmqsc ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
            sleep 3
        done
        MQCHLS=""
    done

}

# ------------------------------------------------------------------------------
# ��~
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x

    MQ_EXEC_FILE=""

    # MQ Object ��~
    for mqmgr in ${MQMGRS}
    do
        # MQ Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}
        MQCHLS="${MQCHLS:-$_OBJ2}"    # MQ Channel

        # MQ Manager Status �擾
        getMQMStatus ${mqmgr}

        if [[ "${mqm_status}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "$mqmgr ${message} Skipping ..."
            MQCHLS=""
            continue
        fi

        # MQ Channel ��~
        for mqchl in ${MQCHLS}
        do
            getMessage "SWC051I";logWriter ${LOGFILE} "${mqchl} ${message}"
            echo "stop channel(${mqchl})" | \
            su - ${MQMUSR} -c "runmqsc ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
            sleep 3
        done 
        MQCHLS=""

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
    for mqmgr in ${MQMGRS}
    do
        # MQ Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}
        MQCHLS="${MQCHLS:-$_OBJS2}"    # MQ Channel

        # MQ Manager Status �擾
        getMQMStatus ${mqmgr}
        if [[ "${MQM_STATUS}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "MQ Manager ${mqmgr} ${message}"
            MQCHLS=""
            continue
        fi

        # MQ Channel Status �擾
        for mqchl in ${MQCHLS}
        do
            getCHLStatus ${mqmgr} ${mqchl}
            getMessage "999009I";logWriter ${LOGFILE} "MQ Channel $mqchl �� ${CHL_STATUS:="STOP"} ��Ԃł��B"
        done 
        MQCHLS=""
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

