#!/bin/ksh
################################################################################
# �@�\�T�v      : errpt��񂩂�syslog�֏����o�����s��
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
EXCLUDE_LIST=${G_SCR_ETC_HOME}/${SCR_NAME}_exclude.lst      # errpt���b�Z�[�W���O���X�g
LOGGER_TAG=errpt                                            # syslog�o�͋L�^�p�^�O������

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo " "
    echo '$1:�G���[�E���O�E�G���g���[����̃V�[�P���X�ԍ�'
    echo '$2:�G���[�E���O�E�G���g���[����̃G���[ ID'
    echo '$3:�G���[�E���O�E�G���g���[����̃N���X (H,S,O,U)'
    echo '$4:�G���[�E���O�E�G���g���[����̃^�C�v (INFO,PEND,PERM,PERF,TEMP,UNKN)'
    # echo '$5:�G���[�E���O�E�G���g���[����̌x��t���O�l'
    echo '$6:�G���[�E���O�E�G���g���[����̃��\�[�X��'
    # echo '$7:�G���[�E���O�E�G���g���[����̃��\�[�X�E�^�C�v'
    # echo '$8:�G���[�E���O�E�G���g���[����̃��\�[�X�E�N���X'
    # echo '$9:�G���[�E���O�E�G���g���[����̃G���[�E���x��'
    echo " "

    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# ���O���X�g�`�F�b�N
# ------------------------------------------------------------------------------
checkExcludeList() {
    # ���O���X�g�����v����s�����擾�B
    if [[ -s ${EXCLUDE_LIST} ]]; then
        #out_flag=$(cat ${EXCLUDE_LIST} | grep -v ^"#" | grep "$errpt_id" | awk '{ if($1 == "'$errpt_id'" && $4 == "'$errpt_class'" ) {print $0}}' | wc -l | sed "s/ //g")
        out_flag=$(cat ${EXCLUDE_LIST} | grep -v ^"#" | grep "$errpt_id" | awk '{ if($1 == "'$errpt_id'" ) {print $0}}' | wc -l | sed "s/ //g")
    else
        # getMessage "999009I";logWriter ${LOGFILE} "���O���X�g ${EXCLUDE_LIST} �̒�`�����݂��Ȃ��悤�ł��B"
        :
    fi
}

# ------------------------------------------------------------------------------
# �G���[�N���X�`�F�b�N
# ------------------------------------------------------------------------------
checkErrorClass() {
    case "${errpt_class}" in
        H)
            class_name="HARD_WARE"
            ;;
        S)
            class_name="SOFT_WARE"
            ;;
        *)
            class_name="OTHER_CLASS"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# �G���[�^�C�v�`�F�b�N
# ------------------------------------------------------------------------------
checkErrorType() {
    case "${errpt_type}" in
        INFO)
            getMessage "WD0300I"
            ;;
        PERM)
            getMessage "WD0399C"
            ;;
        *)
            getMessage "WD0399W"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# ���O�o��
# ------------------------------------------------------------------------------
throwErrpt() {
    out_flag="0"        # �o�͂��邩�ǂ����𔻒f����t���O�����Z�b�g(0=�o�͂���)
    checkExcludeList    # ���O���b�Z�[�W�ɊY�����邩�ǂ����̃t���O�𗧂Ă�B
    
    # ���O�o��
    if [[ "$out_flag" = "0" ]]; then
        checkErrorClass     # �G���[�N���X(HARD, SOFT, Other...)���`�F�b�N���A���b�Z�[�W�֔��f������B
        checkErrorType      # �G���[�^�C�v(INFO, TEMP, UNKN, PERM...)���`�F�b�N���A���b�Z�[�W�֔��f������B
        #logWriter ${LOGFILE} "${class_name} ${message} TYPE=${errpt_type} RESOURCE=${errpt_resource} SQNO=${errpt_sqno} ID=${errpt_id} CLASS=${errpt_class}"
        logWriter ${LOGFILE} "${class_name} ${message} TYPE=${errpt_type} RESOURCE=${errpt_resource} SQNO=${errpt_sqno}"
    fi
}

# ==============================================================================
# ���C������
# ==============================================================================
errpt_sqno=$1
errpt_id=$2
errpt_class=$3
errpt_type=$4
errpt_resource=$5

throwErrpt

exit 0
