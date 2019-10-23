#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď�
# ���s�d�l      : �ʏ�Ăяo���i�����Ȃ��j
# �Ǎ��t�@�C��  : ${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst
# �����t�@�C��  : ${G_SCR_LOG_HOME}/${SCR_NAME}.log
# �߂�l        : 0 �ȊO�ُ͈�I��
# �X�V����      : YYYY/MM/DD    �V�K�쐬
#################################################################################
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
WATCH_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst            # �Ď��Ώۃ��X�g�t�@�C����
TARGET_RESOURCES=                                                   # �Ď��Ώۃ��\�[�X
islock="false"

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [���\�[�X��ʖ�]"
    echo "      CPU=CPU�g�p���Ď�"
    echo "      PAGE=�y�[�W���O�X�y�[�X�g�p���Ď�"
    echo "      FS=�t�@�C���V�X�e���g�p���Ď�"
    echo "      PROC=�v���Z�X�Ď�"
    echo "      PING=�l�b�g���[�N�a�ʊĎ�"
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
        1)  TARGET_RESOURCES="$1"
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
    # �Ď��Ώۃt�@�C�����݃`�F�b�N
    checkFileExist ${WATCH_LIST}
    if [[ $RC -ne 0 ]]; then 
        exit $RC
    fi
}

# ------------------------------------------------------------------------------
# �v���Z�X�Ď�
# ------------------------------------------------------------------------------
watchProcess() {
(( ${DBG_FLG} )) && set -x
    # 臒l�w�肪�����ꍇ��1�v���Z�X�Ƃ݂Ȃ�
    if [[ "$limit_w" = "" ]]; then limit_w=1; fi
    if [[ "$limit_c" = "" ]]; then limit_c=1; fi

    for target in $(echo ${targets} | sed 's/,/ /g')
    do
        checkProcess "${target}"
        if [[ ${procs} -lt $limit_c ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "${target} ${message}"
        elif [[ ${procs} -lt ${limit_w} ]]; then
            getMessage "WD0041W";logWriter ${LOGFILE} "${target} ${message}"
        fi
    done
}

# ------------------------------------------------------------------------------
# �t�@�C���V�X�e���g�p���Ď�
# ------------------------------------------------------------------------------
watchFSUsage() {
(( ${DBG_FLG} )) && set -x

    # ��Ď��t�@�C�����݃`�F�b�N
    checkLckFile ${G_WDLOCK}
    if [[ $? -eq 1 ]]; then
        getMessage "WD0900I";logWriter ${LOGFILE} "FS�g�p����${message}( $targets )"
        return 0
    fi

    mmode_tmp=${MSGMODE}

    for target in $(echo ${targets} | sed 's/,/ /g')
    do
        if [[ "$target" = "$(df ${target} | awk -v NAME="${target}" '$7==NAME {print $7}')" ]]; then
            usage_p=$(df ${target} | awk -v NAME="${target}" '$7==NAME {print $4}' | cut -f 1 -d%)
            if [[ ${usage_p} -gt ${limit_c} ]]; then
                getMessage "WD0061C"; checkDupMsg ${priority} "${target}"; logWriter ${LOGFILE} "${target} ${message}${usage_p}%"
            elif [[ ${usage_p} -gt ${limit_w} ]]; then
                getMessage "WD0061W"; checkDupMsg ${priority} "${target}"; logWriter ${LOGFILE} "${target} ${message}${usage_p}%"
            else
                getMessage "WD0061I"; checkDupMsg ${priority} "${target}"; logWriter ${LOGFILE} "${target} ${message}${usage_p}%"
            fi
        fi
    done

    MSGMODE=${mmode_tmp}
}

# ------------------------------------------------------------------------------
# �y�[�W���O�g�p���Ď�
# ------------------------------------------------------------------------------
watchPaging() {
(( ${DBG_FLG} )) && set -x
    # ��Ď��t�@�C�����݃`�F�b�N
    checkLckFile ${G_WDLOCK}
    if [[ $? -eq 1 ]]; then
        getMessage "WD0900I";logWriter ${LOGFILE} "�y�[�W���O�g�p����${message}"
        return 0
    fi

    usage_p=$(lsps -s|tail -1|awk '{print $2}'|sed 's/\%//g')

    if [[ ${usage_p} -gt ${limit_c} ]]; then
        getMessage "WD0071C";logWriter ${LOGFILE} "${message}${usage_p}%"
    elif [[ ${usage_p} -gt ${limit_w} ]]; then
        getMessage "WD0071W";logWriter ${LOGFILE} "${message}${usage_p}%"
    fi
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

cat ${WATCH_LIST} | egrep "^${HOSTNAME}:|^COMMON:"| egrep "$(echo ${TARGET_RESOURCES}| sed 's/,/|/g')" | while read target_line
do
    kind=$(echo ${target_line}|awk -F: '{print $2}')
    targets=$(echo ${target_line}|awk -F: '{print $3}')
    limit_w=$(echo ${target_line}|awk -F: '{print $4}'|sed 's/\%//g')
    limit_c=$(echo ${target_line}|awk -F: '{print $5}'|sed 's/\%//g')
    freevalue1=$(echo ${target_line}|awk -F: '{print $6}')
    freevalue2=$(echo ${target_line}|awk -F: '{print $7}')

    case "${kind}" in
        PROC|PROC_OS)    
            watchProcess
            ;;
        PAGE)
            watchPaging
            ;;
        FS)
            watchFSUsage
            ;;
        CPU)
            # �o�b�N�O���E���h����
            ${SCR_HOME}/${SCR_NAME}_cpu${G_SCR_SFX} ${limit_w} ${limit_c} ${freevalue1} >/dev/null 2>&1 &
            ;;
        PING)
            # �o�b�N�O���E���h����
            ${SCR_HOME}/${SCR_NAME}_ping${G_SCR_SFX} ${targets} >/dev/null 2>&1 &
            ;;
        *)  
            :
            ;;
    esac

done

exit 0
