#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď�
# ���s�d�l      : �����w��𔺂����ʏ�Ăяo��
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
RC=0                                                        # ���^�[���R�[�h���Z�b�g
NODENAME=                                                   # HAMCP�m�[�h��

# �X�N���v�g�Ǝ����[�J���ϐ���`�u���b�N�i�X�N���v�g���ɈقȂ��`�̕ϐ��Q�j
WATCH_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst            # �Ď��Ώۃ��X�g�t�@�C����
LOGFILE=${G_SCR_LOG_HOME}/monitor.log                       # �X�N���v�g���O�t�@�C����
islock="false"
EXCLUDE_LIST=${G_SCR_ETC_HOME}/${SCR_NAME}_exclude.lst
EXEC_SCRIPTS=

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
# �����`�F�b�N
# ------------------------------------------------------------------------------
checkOptions() {
    case "$#" in
        1)  EXEC_SCRIPTS="$1"
            ;;
        *)  showHelp
            ;;
    esac
    
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"

# HACMP Object �擾(���\�[�X�O���[�v)
getObject ${HOSTNAME} "HACMP" ${HOSTNAME}
RGPS=${_OBJS3}

# HACMP �m�[�h���擾
case ${HOSTNAME} in
    "CIS-PSV-ORD") NODENAME="CIS_PSV_ORD" 
        ;;
    "CIS-PSV-STB") NODENAME="CIS_PSV_STB" 
        ;;
    *)
        ;;
esac

for exec_script in $(echo ${EXEC_SCRIPTS} | sed 's/,/ /g')
do
    if [[ "${RGPS}" = "" ]]; then
        [[ -f ${SCR_HOME}/${exec_script} ]] && ${SCR_HOME}/${exec_script}
    else
        for rgp in ${RGPS}
        do
            rgp_status=$(LANG=C  /usr/es/sbin/cluster/utilities/clRGinfo -s | awk -F: '{ if($1 == "'${rgp}'" && $3 == "'${NODENAME}'") {print $2}}')

            if [[ "${rgp_status}" = "ONLINE" ]]; then
                [[ -f ${SCR_HOME}/${exec_script} ]] && ${SCR_HOME}/${exec_script}
            fi
        done
    fi
done

exit 0
