#!/bin/ksh
################################################################################
# �@�\�T�v      : PowerHA �N��/��~/�ғ��󋵕\��
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
#MW_NAME=HACMP
MW_NAME=PowerHA
NODES=
HACMP_GROUP_STATUS=
HACMP_CURRENT_STATUS=
HACMP_NODE_STATUS=
SERVICE=CIS-PSV-PHA
# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | graceful | takeover | force | status] [�m�[�h�ꗗ]"
    echo "��P�����͕K�{"
    echo "��Q�����͔C�ӂł��B"
    echo "�m�[�h������������ꍇ�̓J���}��؂�Ŏw�肵�ĉ������B"

    getMessage "H00002I";echo "${priority} ${message}"
    exit 0
}

# ------------------------------------------------------------------------------
# �����`�F�b�N
# ------------------------------------------------------------------------------
checkOptions() {
    option="$1"

    case "$#" in
        1)  :
            ;;
        2)  NODES="$2"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} ${NODES}"
    
    if [[ "${NODES}" = "" ]]; then
        NODES=$(${G_HACMP_UTL_HOME}/get_local_nodename)
        #getMessage "999009I";logWriter ${LOGFILE} "�m�[�h���w�肪�������ߎ����擾���s���܂����BNODE=$NODES"
        if [[ "${NODES}" = "" ]]; then
            getMessage "999009W";logWriter ${LOGFILE} "�m�[�h�������݂��Ȃ����ߏ����𒆎~���܂��B"
            exit 99
        fi
    fi
}

# ------------------------------------------------------------------------------
# �N��
# ------------------------------------------------------------------------------
doStart() {
    getMessage "SWC001I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
    
    # �ғ��󋵊m�F
    getStatus >> /dev/null
    if [[ "${HACMP_CURRENT_STATUS}" != "ST_INIT" ]]; then
        getMessage "SWC009I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
    else
        _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_rc.cluster -N -cspoc-n "${NODES}" -A -C yes>> ${LOGFILE} 2>&1;RC=$?

        # -N : �����Ƀf�[���� (inittab �̕ύX�Ȃ�) ���n�����܂��B
        # -cspoc-n : �m�[�h�E���X�g�̎w��
        # -b : �n�����u���[�h�L���X�g���܂��B
        # -i : �N���X�^�[��� ( clinfoES ) �f�[�������A�f�t�H���g�E�I�v�V�����Ŏn�����܂��B
        # -C : �f�t�H���g:interactive   �G���[�������Œ�������:yes
        # -A : ���\�[�X�O���[�v�̊Ǘ��������ōs��


        # ���ʔ���
        if [[ $RC -eq 0 ]]; then
            getMessage "SWC002I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
        else
            getMessage "SWC002C";logWriter ${LOGFILE} "${MW_NAME} ${message}"
            # exit 99
        fi
    fi
}

# ------------------------------------------------------------------------------
# �ʏ��~
# ------------------------------------------------------------------------------
doGraceful() {
    getMessage "SWC051I";logWriter ${LOGFILE} "${option} �I�v�V������ ${MW_NAME} ${message}"

    # �N����Ԋm�F
    getStatus >> /dev/null
    if [[ "${HACMP_CURRENT_STATUS}" != "ST_STABLE" ]]; then
        getMessage "SWC059I";logWriter ${LOGFILE} "${MW_NAME} ${message} STATUS=${HACMP_CURRENT_STATUS}"
    else
        _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_clstop -N -cspoc-n "${NODES}" -s -g >> ${LOGFILE} 2>&1; RC=$?

        # -N  : �����ɃV���b�g�_�E�����܂��B
        # -cspoc-n : �m�[�h�E���X�g�̎w��
        # -s  : �T�C�����g�E�V���b�g�_�E���B�V���b�g�_�E���E���b�Z�[�W�� /bin/wall  ����ău���[�h�L���X�g ���Ȃ��悤��  �w�肵�܂��B�f�t�H���g�ł́A�u���[�h�L���X�g���s���܂��B
        # -g  : �N���X�^�[�E�T�[�r�X����~����A���\�[�X�E�O���[�v�̓I�t���C���ɂȂ�܂��B���\�[�X�͉�� ����܂��� �B
        # -gr : �N���X�^�[�E�T�[�r�X����~����A���\�[�X�E�O���[�v�͎��̃m�[�h�Ɉ����p����܂��B


        # ���ʔ���
        if [[ $RC -eq 0 ]]; then
            getMessage "SWC052I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
        else
            getMessage "SWC052C";logWriter ${LOGFILE} "${MW_NAME} ${message} RC=$RC"
            # exit 99
        fi
    fi
}

# ------------------------------------------------------------------------------
# �e�C�N�I�[�o�[
# ------------------------------------------------------------------------------
doTakeover() {
    getMessage "SWC051I";logWriter ${LOGFILE} "${option} �I�v�V������ ${MW_NAME} ${message}"
    _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_clstop '-N' -cspoc-n ${NODES} '-s' '-gr' >> ${LOGFILE} 2>&1;RC=$?

    # ���ʔ���
    if [[ $RC -ne 0 ]]; then
        getMessage "SWC061I";logWriter ${LOGFILE} "${MW_NAME} ${message} RC=$RC"
        # exit 99
    fi
    
}

# ------------------------------------------------------------------------------
# ������~
# ------------------------------------------------------------------------------
doForce() {
    getMessage "SWC051I";logWriter ${LOGFILE} "${option} �I�v�V������ ${MW_NAME} ${message}"
    
    _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_clstop '-N' -cspoc-n ${NODES} '-s' '-f' >> ${LOGFILE} 2>&1;RC=$?
    
    # ���ʔ���
    if [[ $RC -ne 0 ]]; then
        getMessage "SWC061I";logWriter ${LOGFILE} "${MW_NAME} ${message} RC=$RC"
        # exit 99
    fi
}

# ------------------------------------------------------------------------------
# �X�e�[�^�X�m�F
# ------------------------------------------------------------------------------
getStatus() {
    MSGMODE=""
    ${G_HACMP_UTL_HOME}/clcheck_server cthags > /dev/null 2>&1; RC=$?
    if [[ $RC -ne 0 ]]; then
        #${G_HACMP_UTL_HOME}/cllssvcs > /dev/null 2>&1; RC=$?
        netstat -i | grep -w ${SERVICE} > /dev/null 2>&1; RC=$?
        if [[ $RC -eq 0 ]]; then
            HACMP_NODE_STATUS="Service"
            getMessage "SWC019I";logWriter ${LOGFILE} "${HOSTNAME} �� PowerHA Service Node �Ƃ��Ċ������ł��B"
        else
            HACMP_NODE_STATUS="Stanby"
            getMessage "SWC019I";logWriter ${LOGFILE} "${HOSTNAME} �� PowerHA Stanby Node �Ƃ��Ċ������ł��B"
        fi
    else
        getMessage "SWC059I";logWriter ${LOGFILE} "PowerHA ${message}"
    fi
    
    HACMP_CURRENT_STATUS=$(export LANG=C; lssrc -ls clstrmgrES  | grep "Current state:" | awk '{print $3}')
    getMessage "999009I";logWriter ${LOGFILE} "PowerHA CURRENT STATUS=${HACMP_CURRENT_STATUS}"
    #echo "ST_INIT=��~���   ST_RP_RUNNING=�N���r��   ST_STABLE=�N�������ŃX�e�[�u�����   ST_BARRIER=�C�x���g��Q���H  ST_RP_FAILED=�C�x���g�X�N���v�g�����s���Ă���Ȃ�"
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
    stop|graceful)
        doGraceful
        ;;
    takeover)
        doTakeover
        ;;
    force)
        doForce
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

