#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď�
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
WATCH_LIST=${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst         # �Ď��Ώۃ��X�g�t�@�C����
TARGETS=

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [�z�X�g��]"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# �����`�F�b�N
# ------------------------------------------------------------------------------
checkOptions() {
(( ${DBG_FLG} )) && set -x
    case "$#" in
        0)  :
            ;;
        1)  TARGETS="$1"
            ;;
        *)  showHelp
            ;;
    esac

}

# ------------------------------------------------------------------------------
# �X�N���v�g������
# ------------------------------------------------------------------------------
initializer() {
(( ${DBG_FLG} )) && set -x
}

# ------------------------------------------------------------------------------
# ping�Ď�
# ------------------------------------------------------------------------------
watchPing() {
(( ${DBG_FLG} )) && set -x
    ping -5 "$1"
    if [[ $? -ne 0 ]]; then 
        getMessage "WD0021C";logWriter ${LOGFILE} "$1 $2 ${message}"
    fi
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

if [[ "TARGETS" = "" ]]; then
    # �Ď��Ώۃt�@�C�����݃`�F�b�N
    checkFileExist ${WATCH_LIST}
    if [[ $RC -ne 0 ]]; then exit 0; fi
    
    cat ${WATCH_LIST} | egrep -v "^#|^$|^ " | while read ip name
    do
        watchPing "${ip}" "${name}"
    done
else
    for ip in $(echo "${TARGETS}" | sed 's/,/ /g')
    do
        watchPing "${ip}" "-"
    done

fi

exit 0
