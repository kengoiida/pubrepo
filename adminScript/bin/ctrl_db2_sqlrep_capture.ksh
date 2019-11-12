#!/bin/ksh
################################################################################
# �@�\�T�v      : SQL Replication Capture Program �N��/��~/�m�F
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
MW_NAME="SQLCAP"

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | restart | status] [DB��] [cold | warmsi | warmns]"
    echo "����1:�����ʂ��w�肵�ĉ������B"
    echo "����2:�L���v�`���[�T�[�o�[���i�f�[�^�x�[�X���j���w�肵�ĉ������B"
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
        2)  REP_SVRS="$2"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option}"
    
    # ��Q�����w�肪�����ꍇ�͓o�^���X�g����T�[�o�[(DB)�ꗗ���擾����B
    if [[ "${REP_SVRS}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVRS="$_OBJ1"
    fi

}

# ------------------------------------------------------------------------------
# �N��
# ------------------------------------------------------------------------------
doStart() {
(( ${DBG_FLG} )) && set -x

    getMessage "SWC001I";logWriter ${LOGFILE} "CAPTURE PROGRAM ${message}"

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do

        # SQL-REP CAPTURE ���擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"
        _schema="$_OBJ2"
        _path="$_OBJ4"

        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            su - "${_user}" -c "nohup asncap capture_server=${svr} capture_schema=${_schema} capture_path=${_path} autostop=n commit_interval=30 logreuse=n startmode=warmsi &" >> ${LOGFILE} 2>&1;_rc=$?
            if [[ $_rc -ne  0 ]]; then
                RC=$(($RC+$_rc)); getMessage "SWC002C";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} RC=$RC"
            else
                getMessage "SWC002I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
            fi
            sleep 5
        else
            getMessage "SWC009I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
        fi

    done

    if [[ $RC -ne  0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${REP_SVRS} ${message}"; fi
}

# ------------------------------------------------------------------------------
# ��~
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x

    getMessage "SWC051I";logWriter ${LOGFILE} "Capture Program ${message}"

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do

        # SQL-REP CAPTURE ���擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"
        _schema="$_OBJ2"
        _path="$_OBJ4"

        checkProcess ${MW_NAME} "${svr}"
        if [[ ${procs} -ne 0 ]]; then
            su - "${_user}" -c "asnccmd capture_schema=${_schema} capture_server=${svr} stop" >>${LOGFILE} 2>&1;RC=$?
            if [[ $RC -ne  0 ]]; then
                getMessage "SWC052C";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} RC=$RC"
                exit 99
            fi
        else
            getMessage "SWC059I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
            continue
        fi

        for i in 1 2 3 4 5 6 7 8 9 10; do
            sleep 2
            checkProcess ${MW_NAME} "${svr}"
            if [[ "${procid}" = "" ]]; then
                getMessage "SWC052I";logWriter ${LOGFILE} "${CAP_SVR} CAPTURE PROGRAM ${message}"
                break
            else
                if [ $i -ge 10 ]; then getMessage "SWC052C";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} PRC-ID=${procid}";exit 99; fi
            fi
        done
    done
}

# ------------------------------------------------------------------------------
# �ċN��
# ------------------------------------------------------------------------------
doRestart() {
    :
}

# ------------------------------------------------------------------------------
# �X�e�[�^�X�m�F
# ------------------------------------------------------------------------------
getStatus() {
(( ${DBG_FLG} )) && set -x

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        checkProcess ${MW_NAME} "${svr}"
        if [[ ${procs} -ne 0 ]]; then
            getMessage "SWC009I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} PROC-ID=${procid}"
        else
            getMessage "SWC059I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
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
