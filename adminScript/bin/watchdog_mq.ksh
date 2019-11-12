#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď� for MQ
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
MW_NAME="MQM"
KEYWORD=
MQMUSR=mqm  # MQ Manager User Default
MQMGRS=     # MQ Manager
MQLSNP=     # MQ Listner Port No
MQCHLS=     # MQ Channel
MQQUES=     # MQ Queue

SYSLOG_FACILITY=local5
# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [MQ�}�l�[�W���[��]"
    echo "�����͔C�ӂł��B    �w�肪�����ꍇ�͓o�^���X�g���Q�Ƃ���܂��B"
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
        1)  MQMGRS="$1"
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

    # ��P�����w�肪�����ꍇ�͓o�^���X�g����MQ Manager �ꗗ���擾����B
    if [[ "${MQMGRS}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        MQMUSR=$_OBJ1      # MQ User
        MQMGRS=$_OBJ2      # MQ Manager
    fi    

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

watchMQStatus       # ���ʊ֐����C�u�����[�ɓo�^���ꂽ�֐�

finalizer
exit 0
