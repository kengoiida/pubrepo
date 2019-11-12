#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď�(CPU)
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
limit_w=80                                                  # �x��臒l�̏ȗ��l
limit_c=95                                                  # �댯臒l�̏ȗ��l
cputime=30                                                  # �C���^�[�o���ȗ��l

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [WARNING_LIMIT] [CRITICAL_LIMIT] [INTERVAL_SECOND]" 
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# �����`�F�b�N
# ------------------------------------------------------------------------------
checkOptions() {
    if [[ "$1" != "" ]]; then limit_w="$1"; fi
    if [[ "$2" != "" ]]; then limit_c="$2"; fi
    if [[ "$3" != "" ]]; then cputime="$3"; fi
}

# ------------------------------------------------------------------------------
# CPU�g�p���Ď�
# ------------------------------------------------------------------------------
watchCPU() {
(( ${DBG_FLG} )) && set -x
    usage_p=$(/usr/sbin/sar ${cputime} 1 | tail -1 | awk '{print $2+$3+$4}')

    if [[ ${usage_p} -ge ${limit_c} ]]; then
        getMessage "WD0051C";logWriter ${LOGFILE} "CPU ${message}${usage_p}%"
        #nohup tprof -skeuj -r ${G_SCR_LOG_HOME}/tprof_$(hostname)_$(date +%Y%m%d%H%M%S).txt -x sleep 10 &
    elif [[ ${usage_p} -ge ${limit_w} ]]; then
        getMessage "WD0051W";logWriter ${LOGFILE} "CPU ${message}${usage_p}%"
        #nohup tprof -skeuj -r ${G_SCR_LOG_HOME}/tprof_$(hostname)_$(date +%Y%m%d%H%M%S).txt -x sleep 10 &
    fi
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"

watchCPU

exit 0
