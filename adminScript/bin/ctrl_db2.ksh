#!/bin/ksh
###################################################################################
# �@�\�T�v      : DB2 �N��/��~/�m�F
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
MW_NAME="DB2"
INSTANCES=
INSTHOME=
DBNAMES=
PASSWORD=
# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | stopforce | stopkill | restart | status] [�C���X�^���X��]"
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
        2)  INSTANCES="$2"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} ${INSTANCES}"

    # ��Q�����w�肪�����ꍇ�̓z�X�g�����L�[���[�h��OBJECT���X�g����INSTANCE �ꗗ���擾����B
    if [[ "${INSTANCES}" = "" ]]; then
        # DB2 Instance �擾
        getObject ${HOSTNAME} ${MW_NAME}
        INSTANCES="$_OBJ1"
    fi
}

# ------------------------------------------------------------------------------
# �N��
# ------------------------------------------------------------------------------
doStart() {
(( ${DBG_FLG} )) && set -x
    for inst in $(echo "${INSTANCES}" | sed "s/,/ /g")
    do
        getMessage "SWC001I";logWriter ${LOGFILE} "${inst} ${message}"

        # INSTANCE���擾
        getInstInfo ${inst}
        
        #echo "0 ${HOSTNAME} 0" >  ${INSTHOME}/sqllib/db2nodes.cfg
        # INSTANCE�ғ��m�F
        checkProcess ${MW_NAME} ${inst}
        if [[ ${procs} -eq 0 ]]; then

            # INSTANCE�N��
            su - "${inst}" -c "db2start" >> ${LOGFILE} 2>&1; _rc=$?
            if [[ $_rc -eq  0 ]]; then
                #doActivate
                getMessage "SWC002I";logWriter ${LOGFILE} "${inst} ${message}"
            else
                RC=$(($RC+$_rc)); getMessage "SWC002C";logWriter ${LOGFILE} "${inst} ${message} RC=$RC"
            fi
        else
            getMessage "SWC009I";logWriter ${LOGFILE} "${inst} ${message}"
        fi
    done

    if [[ $RC -ne  0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${INSTANCES} ${message}"; fi

}

# ------------------------------------------------------------------------------
# DB������
# ------------------------------------------------------------------------------
doActivate() {
(( ${DBG_FLG} )) && set -x
    for dbname in $(echo "${DBNAMES}" | sed "s/,/ /g")
    do
        su - "${inst}" -c "db2 activate database ${dbname}" >> ${LOGFILE} 2>&1; _rc=$?
        if [[ $_rc -eq  0 ]]; then
            getMessage "SWC012I";logWriter ${LOGFILE} "${dbname} ${message}"
        else
            RC=$(($RC+$_rc)); getMessage "SWC012C";logWriter ${LOGFILE} "${dbname} ${message} RC=$RC"
        fi
    done

    if [[ $RC -ne  0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${DBNAMES} ${message}"; fi
}

# ------------------------------------------------------------------------------
# ��~
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x
    for inst in $(echo "${INSTANCES}" | sed "s/,/ /g")
    do

        # INSTANCE���擾
        getInstInfo ${inst}

        getMessage "SWC051I";logWriter ${LOGFILE} "${inst} ${message}"
        
        checkProcess ${MW_NAME} ${inst}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "SWC059W";logWriter ${LOGFILE} "${inst} ${message}"
        else
            case "${option}" in
                stop)
                    for try in 1 2
                    do
                        sleep 1
                        su - "${inst}" -c "db2 -v force application all" >> ${LOGFILE} 2>&1; _rc=$?
                    done

                    su - "${inst}" -c "db2stop" >> ${LOGFILE} 2>&1; _rc=$?
                    ;;
                stopforce)
                    su - "${inst}" -c "db2stop force" >> ${LOGFILE} 2>&1; _rc=$?
                    ;;
                stopkill)
                    su - "${inst}" -c "db2kill" >> ${LOGFILE} 2>&1; _rc=$?
                    ;;
                *)
                    showHelp
                    ;;
            esac

            if [[ $_rc -eq  0 ]]; then
                getMessage "SWC052I";logWriter ${LOGFILE} "${inst} ${message}"
            else
                RC=$(($RC+$_rc)); getMessage "SWC052C";logWriter ${LOGFILE} "${inst} ${message} RC=$RC"
            fi
        fi

    done
            
    if [[ $RC -ne 0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${INSTANCES} ${message}"; fi
}

# ------------------------------------------------------------------------------
# �ċN��
# ------------------------------------------------------------------------------
doRestart() {
(( ${DBG_FLG} )) && set -x
    option="stop"; doStop; option="restart"; sleep 5; doStart
}

# ------------------------------------------------------------------------------
# �X�e�[�^�X�m�F
# ------------------------------------------------------------------------------
getStatus() {
(( ${DBG_FLG} )) && set -x

    MSGMODE=""

    for inst in ${INSTANCES}
    do

        # INSTANCE���擾
        getInstInfo ${inst}

        # PWD�擾
        getPassword ${HOSTNAME} ${inst}

        # �v���Z�X�`�F�b�N
        checkProcess ${MW_NAME} ${inst}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "${inst} ${message}"; _rc=$?; RC=$(($RC+$_rc))
        else 
            getMessage "WD0041I";logWriter ${LOGFILE} "${inst} ${message}"
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
    stop|stopforce|stopkill)
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

exit $RC
