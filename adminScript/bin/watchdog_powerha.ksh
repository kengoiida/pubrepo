#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď� for HACMP
# ���s�d�l      : �ʏ�Ăяo���i�����Ȃ��j
# �Ǎ��t�@�C��  : ${G_SCR_ETC_HOME}/watchdog_target.lst
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
MW_NAME="HACMP"

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0)"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# HACMP �ғ��m�F
# ------------------------------------------------------------------------------
watchHAStatus() {
    ${G_HACMP_UTL_HOME}/clcheck_server cthags > /dev/null 2>&1
    RC=$?
    if [[ ${RC} -eq 0 ]]; then
        getMessage "WD0041C";logWriter ${LOGFILE} "PowerHA ${message} " 
        return 99
    fi
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

watchHAStatus; RC=$?

exit $RC
