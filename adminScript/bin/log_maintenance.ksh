#!/bin/ksh
################################################################################
# �@�\�T�v      : ���O�����e�i���X
# ���s�d�l      : �ʏ�Ăяo���i�����Ȃ��j
# �Ǎ��t�@�C��  : ${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst
# �����t�@�C��  : ${G_SCR_LOG_HOME}/${SCR_NAME}.log
# �߂�l        : 0 �ȊO�ُ͈�I��
# �X�V����      : YYYY/MM/DD    �V�K�쐬
################################################################################
# �O���t�@�C���Ǎ��E�ϐ���`
SCR_HOME=$(dirname $0)

[[ -f /.profile ]] && . /.profile >/dev/null
. ${SCR_HOME}/_common_profile.conf
. ${SCR_HOME}/${G_SCR_LIB}

# �X�N���v�g���ʃ��[�J���ϐ���`�u���b�N�i��{�I�ɑS�ẴX�N���v�g�Œ�`���ׂ��ϐ��Q�j
SCR_NAME=$(basename $0 ${G_SCR_SFX})                        # �X�N���v�g���擾
HOSTNAME=$(hostname)                                        # �z�X�g���擾
MSGLIST=${G_SCR_ETC_HOME}/${G_SCR_MSG}                      # �X�N���v�g���b�Z�[�W��`�t�@�C����
MSGMODE=${G_MSGMODE}                                        # ���b�Z�[�W�o�̓��[�h
LOGDATE=$(date +%Y%m%d)                                     # �X�N���v�g���O�t�@�C�����Ƀ^�C���X�^���v���܂߂�ꍇ�g�p������t�B
LOGFILE=${G_SCR_LOG_HOME}/${SCR_NAME}.log                   # �X�N���v�g���O�t�@�C����
LOGGER_TAG=${SCR_NAME}                                      # syslog�o�͋L�^�p�^�O������
RC=0                                                        # ���^�[���R�[�h���Z�b�g

# �X�N���v�g�Ǝ����[�J���ϐ���`�u���b�N�i�X�N���v�g���ɈقȂ��`�̕ϐ��Q�j
TARGET_LIST="${G_SCR_ETC_HOME}/log_maintenance.lst"         # �����e�i���X���X�g
#MSGMODE=nologging                                           # 
SYSLOG_FACILITY=local6
# ------------------------------------------------------------------------------
# ���[�e�[�V�����E�T�u�֐�
# ------------------------------------------------------------------------------
doLogRotate() {
    target_dir="$2"
    target_file="$3"

    FIND_LIST=$(find ${target_dir} -name "${target_file}")

    for file in $(echo ${FIND_LIST})
    do
        rcount=$1

        if [[ ${rcount} -eq 0 ]]; then
            cp -p ${file} ${file}.$(date '+%Y%m%d_%H%M%S')
        else
            while [ ${rcount} != 1 ]
            do
                [[ -f ${file}.$((rcount-1)) ]] && {
                    cp -p ${file}.$((rcount-1)) ${file}.${rcount}
                }
                ((rcount-=1))
            done
            [ -f ${file} ] && cp -p ${file} ${file}.${rcount}
        fi

        cat /dev/null > ${file}
    done
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

[[ ! -f ${TARGET_LIST} ]] && {
#    MSGMODE=syslog
    getMessage "LOG000C";logWriter ${LOGFILE} "���X�g�t�@�C�������݂��܂���B[${TARGET_LIST}]"
    exit 1
}

#getMessage "LOG000I";logWriter ${LOGFILE} "���O�����e�i���X�������J�n���܂��B"

for MNTLIST in $(cat ${TARGET_LIST}|awk -F: '{ if($1 == "COMMON" || $1 == "'$HOSTNAME'" ){print $0}}')
do
	type=$(echo ${MNTLIST} |  awk -F: '{ print $2 }')	# �����e�i���X�^�C�v
	expire=$(echo ${MNTLIST} |  awk -F: '{ print $3 }')	# �L������ or �L����
	dir=$(echo ${MNTLIST} |  awk -F: '{ print $4 }')	# �Ώۃf�B���N�g��
	file=$(echo ${MNTLIST} |  awk -F: '{ print $5 }')	# �t�@�C�����i���C���h�J�[�h�j

    [[ ! -d ${dir} ]] && continue

    case ${type} in
        delete)
            find ${dir} -name "${file}" -mtime +${expire} -exec rm -f {} \;
            ;;
        daily)
            doLogRotate ${expire} ${dir} "${file}"
            ;;
        weekly*)
            [[ "$(date +%w)" = "$(echo ${type} | cut -c 7-)" ]] && {
                doLogRotate ${expire} ${dir} "${file}"
            }
            ;;
        *)
            ;;
    esac

done

# ��Ď����b�N�t���O�t�@�C���폜
#deleteLckFile "watchdog_aix"
#deleteLckFile "watchdog_db2"

#getMessage "LOG000I";logWriter ${LOGFILE} "���O�����e�i���X�������I�����܂��B"

exit 0

