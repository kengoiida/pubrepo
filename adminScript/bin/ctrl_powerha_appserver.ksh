#!/bin/ksh
################################################################################
# �@�\�T�v      : �N���X�^�[�Ώۃ~�h���E�F�A�N��/��~
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

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop]"
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
        *)  showHelp
            ;;
    esac
}

# ------------------------------------------------------------------------------
# �X�N���v�g������
# ------------------------------------------------------------------------------
initializer() {
    :
    #getMessage "000001I";logWriter ${LOGFILE} "${message}"
    #getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option}"
}

# ------------------------------------------------------------------------------
# �N��
# ------------------------------------------------------------------------------
doStart() {
    getMessage "SWC001I";logWriter ${LOGFILE} "�N���X�^�[�Ώۃ~�h���E�F�A${message}"
    ${SCR_HOME}/ctrl_db2.ksh start
    ${SCR_HOME}/ctrl_mqm.ksh start
    ${SCR_HOME}/ctrl_mqchl.ksh start
    ${SCR_HOME}/ctrl_db2_sqlrep_capture.ksh start
}

# ------------------------------------------------------------------------------
# ��~
# ------------------------------------------------------------------------------
doStop() {
    getMessage "SWC051I";logWriter ${LOGFILE} "�N���X�^�[�Ώۃ~�h���E�F�A${message}"
    ${SCR_HOME}/ctrl_db2_sqlrep_capture.ksh stop
    ${SCR_HOME}/ctrl_mqchl.ksh stop
    ${SCR_HOME}/ctrl_mqm.ksh stop
    ${SCR_HOME}/ctrl_db2.ksh stop
}

# ------------------------------------------------------------------------------
# �X�N���v�g�I������
# ------------------------------------------------------------------------------
finalizer() {
    :
    #getMessage "000099I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} RC=${RC}"
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
    *)
        showHelp
        ;;
esac

finalizer

exit 0
