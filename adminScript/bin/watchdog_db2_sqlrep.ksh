#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď� for SQL-Replication
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
MW_NAME="SQLREP"
DB2_PROFILE=~/sqllib/db2profile
PASSWORD=
QRPRCS=
REP_SVR=
exclude_list=''
# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [ �f�[�^�x�[�X�� ]"
    echo "��P�����͔C�ӂł��B�w�肪�����ꍇ�͓o�^���X�g���`�F�b�N����܂��B"
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
        1)  REP_SVRS="$1"
            ;;
        *)  showHelp
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Caputure Server Status�m�F
# ------------------------------------------------------------------------------
watchCAPStatus() {
(( ${DBG_FLG} )) && set -x
    
    MW_NAME="SQLCAP"
    
    # ��P�����w�肪�����ꍇ�͓o�^���X�g���烌�v���P�[�V�����v���Z�X�ꗗ���擾����B
    if [[ "${REP_SVRS}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVRS="$_OBJS1"   # �L���v�`���[�T�[�o�[�ꗗ
        if [[ "${REP_SVRS}" = "" ]]; then return; fi
    fi

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        cat ${WATCH_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'$svr'" ) {print $3}}' | read wdtarget

        if [[ "$wdtarget" = "" ]]; then
            getMessage "WD0999I";logWriter ${LOGFILE} "SQL-Rep Capture Server ${svr} �͊Ď��Ώۂł͂���܂���B"; continue
        fi

        # SQL-rep�v���Z�X�m�F
        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "SQL-Rep Caputure Server ${svr} ${message}"
        fi

    done
}

# ------------------------------------------------------------------------------
# Apply Server Status�m�F
# ------------------------------------------------------------------------------
watchAPPStatus() {
(( ${DBG_FLG} )) && set -x

    MW_NAME="SQLAPP"

    # ��P�����w�肪�����ꍇ�̓z�X�g�����烌�v���P�[�V�����v���Z�X�ꗗ���擾����B
    if [[ "${REP_SVRS}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVRS=$_OBJS1     # �A�v���C�v���Z�X�ꗗ �擾
        if [[ "${REP_SVRS}" = "" ]]; then return; fi
    fi    

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        cat ${WATCH_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'$svr'" ) {print $3}}' | read wdtarget

        if [[ "$wdtarget" = "" ]]; then
            getMessage "WD0999I";logWriter ${LOGFILE} "SQL-Rep Apply Server ${svr} �͊Ď��Ώۂł͂���܂���B"; continue
        fi

        # Rep Object �擾
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"
        _schema="$_OBJ2"
        _path="$_OBJ4"

        # �T�u�X�N���v�V�����X�e�[�^�X�m�F
        if [[ "${G_SQLCAP_TBL_SUBSET}" != "" ]]; then
            tmp_sql="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_SQLCAP_TBL_SUBSET}.sql"
            tmp_sub="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_SQLCAP_TBL_SUBSET}.tmp"
            echo "connect to ${svr};" > ${tmp_sql}
            echo "select count(*) from ${_schema}.${G_SQLCAP_TBL_SUBSET} where member_state = 'D';" >> ${tmp_sql}
            echo "terminate;" >> ${tmp_sql}
            su - ${_user} -c "db2 -tvf ${tmp_sql}" > ${TMP_LIST}
            noact=$(cat ${TMP_LIST}|awk '/^select/ { getline; print }' | sed 's/ //g')
            if [[ ${noact} -ne 0 ]]; then
                getMessage "999009W";logWriter ${LOGFILE} "SQL-Rep [${_user}] �񊈓���Ԃ̃T�u�X�N���v�V������ ${noact}������܂��B"
                RC=3
            fi
        fi

    done
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"

watchCAPStatus
watchAPPStatus

exit 0

