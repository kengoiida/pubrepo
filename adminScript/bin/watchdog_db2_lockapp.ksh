#!/bin/ksh
################################################################################
# �@�\�T�v      : �^�p�Ď� for DB2
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
TARGET_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst           # �Ď��Ώۃ��X�g�t�@�C����
MW_NAME="DB2"
WATCH_KIND="DB2_LOCK"
INSTANCES=
DBNAMES=
PASSWORD=
limit_w=120

# ------------------------------------------------------------------------------
# �w���v�\��
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [�C���X�^���X��]"
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
        1)  INSTANCES="$1"
            ;;
        *)  showHelp
            ;;
    esac

    # �Ď��Ώۃt�@�C�����݃`�F�b�N
    checkFileExist ${TARGET_LIST}; RC=$?
    if [[ $RC -ne 0 ]]; then 
        exit $RC
    fi

}

# ------------------------------------------------------------------------------
# �X�N���v�g������
# ------------------------------------------------------------------------------
initializer() {

    getObject ${HOSTNAME} ${MW_NAME}
    if [[ "${INSTANCES}" = "" ]]; then INSTANCES=$_OBJ1; fi     # ��P�����w�肪�����ꍇ�͓o�^���X�g����INSTANCE �ꗗ���擾����B

    # ��Ď��t�@�C�����݃`�F�b�N
    checkLckFile ${G_WDLOCK}
    if [[ $? -eq 1 ]]; then
        exit 0
    fi

}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

for inst in ${INSTANCES}
do
    cat ${TARGET_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'" && $3 == "'$inst'" ) {print $3}}' | read wdtarget

    if [[ "$wdtarget" = "" ]]; then continue; fi
    limit_w=$(echo "$wdtarget"|awk -F: '{print $4}}'

    # INSTANCE���擾
    getInstInfo ${inst}     # DBNAMES�擾

    # PWD�擾
    getPassword ${HOSTNAME} ${inst}

    for dbname in $(echo ${DBNAMES} | sed 's/,/ /g')
    do
        watchDB2LockStatus ${dbname}
    done
done

exit 0
