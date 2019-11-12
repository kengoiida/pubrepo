#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď� for TSM
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
TARGET_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst           # �Ď��Ώۃ��X�g�t�@�C����
MW_NAME="TSM"
TSM_USR=${G_TSM_USR:=admin}
DSMADMC="dsmadmc -id=$TSM_USR"
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
    :
}

# ------------------------------------------------------------------------------
# �X�N���v�g������
# ------------------------------------------------------------------------------
initializer() {
    getMessage "000001I";logWriter ${LOGFILE} "${message}"
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME}"

    getPassword ${HOSTNAME} ${TSM_USR}
    DSMADMC="${DSMADMC} -password=${PASSWORD}"
}

# ------------------------------------------------------------------------------
# TSM�ڑ��m�F
# ------------------------------------------------------------------------------
watchTSMConnect() {
    ${DSMADMC} quit > /dev/null 2>&1; RC=$?
    if [[ $RC -eq  0 ]]; then
        getMessage "WD0011I";logWriter ${LOGFILE} "TSM Server ${message}"
    else
        # �ڑ��o���Ȃ��ꍇ�͑��I���Ƃ���B
        getMessage "WD0011C";logWriter ${LOGFILE} "TSM Server ${message}"
        finalizer
        exit $RC
    fi
}

# ------------------------------------------------------------------------------
# TSM���f�B�A��Ԋm�F
# ------------------------------------------------------------------------------
watchTSMVolStatus() {

    VOL_LIST=$(${DSMADMC} q vol access=unav,des | awk '$3=="'$G_TSM_DEV'" { print $1 }')
    for vol in ${VOL_LIST}
    do
        getMessage "WD0401C";logWriter ${LOGFILE} "${vol} ${message}"; RC=99
    done
}

# ------------------------------------------------------------------------------
# TSM�X�g���[�W�v�[���g�p���m�F
# ------------------------------------------------------------------------------
watchTSMPoolUsage() {
    WATCH_KIND="TSM_STGPOOL"

    cat ${TARGET_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'"){print $3,$4,$5}}'|sed 's/\%//g'|while read targets limit_w limit_c
    do
        if [[ "${stgpools}" = "" ]]; then
            targets=$(${DSMADMC} query stgpool | grep "Primary" |awk '{print $1}'|tr '\n' ',')
        fi

        for pool in $(echo "$targets" | sed "s/,/ /g")
        do
            usage_p=$(${DSMADMC} query stgpool ${pool}| grep "Primary" |awk '{print $7}')
            if [[ ${usage_p} -gt ${limit_c} ]]; then
                getMessage "WD0081C";logWriter ${LOGFILE} "$pool ${message}  ${usage_p}%"; RC=99
            elif [[ ${usage_p} -gt ${limit_w} ]]; then
                getMessage "WD0081W";logWriter ${LOGFILE} "$pool ${message}  ${usage_p}%"; RC=99
            else
                getMessage "WD0081I";logWriter ${LOGFILE} "$pool ${message}  ${usage_p}%"
            fi
        done
    done
}

# ------------------------------------------------------------------------------
# TSM�󂫖{���m�F
# ------------------------------------------------------------------------------
watchTSMScratchVol() {
    WATCH_KIND="TSM_VOLEMPTY"
    
    cat ${TARGET_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'"){print $3,$4,$5}}'|sed 's/\%//g'|while read targets limit_w limit_c
    do
        unused_vol=$(${DSMADMC} q libvolume ${G_TSM_LIB} | awk 'BEGIN { NUM=0 } { if( $1=="'$G_TSM_LIB'" && $3=="�X�N���b�`" ) NUM=NUM+1; } END { print NUM }')

        if [[ "$unused_vol" = "" ]]; then
            getMessage "999009W";logWriter ${LOGFILE} "TSM �󂫃e�[�v�{�����擾�o���܂���ł����B"; RC=99
        else
            if [[ ${unused_vol} -lt ${limit_c} ]]; then
                getMessage "WD0082C";logWriter ${LOGFILE} "${message}${unused_vol}�{�ł��B"; RC=99
            elif [[ ${unused_vol} -lt ${limit_w} ]]; then
                getMessage "WD0082W";logWriter ${LOGFILE} "${message}${unused_vol}�{�ł��B"; RC=99
            else
                getMessage "WD0082I";logWriter ${LOGFILE} "${message}${unused_vol}�{�ł��B"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# TSM DB�g�p��
# ------------------------------------------------------------------------------
watchTSMDbUsage() {
    WATCH_KIND="TSM_DB"
    
    cat ${TARGET_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'"){print $3,$4,$5}}'|sed 's/\%//g'|while read targets limit_w limit_c
    do
        used_p=$(${DSMADMC} -displ=list "SELECT USED_PAGES,USABLE_PAGES FROM DB" |awk -F: 'BEGIN{usedpg = 0; usablepg = 0} {if($1 == "  USED_PAGES"){usedpg = $2 }; if($1 == "USABLE_PAGES"){usablepg = $2 }} END {print usedpg / usablepg * 100 }')

        if [[ "${used_p}" = "" ]]; then
            getMessage "999009W";logWriter ${LOGFILE} "TSM DB �̎g�p�����擾�o���܂���ł����B"; RC=99
        else
            if [[ ${used_p} -gt ${limit_c} ]]; then
                getMessage "WD0051C";logWriter ${LOGFILE} "TSM DB ${message}${used_p}%"; RC=99
            elif [[ ${used_p} -gt ${limit_w} ]]; then
                getMessage "WD0051W";logWriter ${LOGFILE} "TSM DB ${message}${used_p}%"; RC=59
            else
                getMessage "WD0051I";logWriter ${LOGFILE} "TSM DB ${message}${used_p}%"
            fi
        fi
    done
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

watchTSMConnect
watchTSMDbUsage
watchTSMScratchVol
watchTSMVolStatus
#watchTSMPoolUsage

finalizer
exit $RC
