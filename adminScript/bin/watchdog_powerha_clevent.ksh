#!/bin/ksh
################################################################################
# �@�\�T�v      : �N���X�^�[�C�x���g�ʒm
# ���s�d�l      : �ʏ�Ăяo���iPowerHA����n����������ǂݍ��ށj
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
LOGGER_TAG="HACMP"                                          # syslog�o�͋L�^�p�^�O������
UTL_HOME=${G_HACMP_UTL_HOME}
LOCAL="$(${UTL_HOME}/get_local_nodename)"
OTHER="$(${UTL_HOME}/clnodename | grep -v ${LOCAL})"

# ------------------------------------------------------------------------------
# �����`�F�b�N
#   $1 : event_name
#   $2 : mode (start/complete)
#   $3 : option 1
#   $4 : option 2
#   $5 : option 3
# ------------------------------------------------------------------------------
checkClusterEvent() {
(( ${DBG_FLG} )) && set -x

    getMessage "WDH000I"    # �_�~�[���b�Z�[�W(priority�擾)
    message_tmp="${message} ARG1=$1  ARG2=$2  ARG3=$3  ARG4=$4  ARG5=$5"
        
    case "$1" in
        node_up)
            # 1) node_up start localnode  >>> node_up start
            if [[ $2 == "start" && $3 == ${LOCAL} ]]; then
                getMessage "WDH001I"
            fi
            ;;

        node_up_complete)
            # 1) node_up_complete complete 0 localnode >>> node_up end (normal)
            # 2) node_up_complete complete 1 localnode >>> node_up end (abnormal)
            if [[ $2 == "complete" && $4 == ${LOCAL} ]]; then
                case $3 in
                    0) getMessage "WDH002I" ;;
                    1) getMessage "WDH003C" ;;
                    *) ;;
                esac
            fi
            ;;

        node_down)
            # 1) node_down start localnode >>> node_down start
            if [[ $2 == "start" ]]; then
                case $3 in
                    ${LOCAL}) getMessage "WDH011I" ;;
                    *) ;;
                esac
            fi
            ;;

        node_down_complete)
            # 1) node_down_complete complete 0 localnode >>> node_down end (normal)		#
            # 2) node_down_complete complete 1 localnode >>> node_down end (abnormal)	#
            if [[ $2 == "complete" ]]; then
                #if [[ $4 == ${LOCAL} ]]; then
                    case $3 in
                    0) getMessage "WDH012I"
                         message="PowerHA node_down normal end.[ $4 ]"
                         ;;
                    1) getMessage "WDH013C"
                         message="PowerHA node_down abnormal end. [ $4 ]"
                         ;;
                    *) ;;
                    esac
                #else
                #    getMessage "WDH013C"
                #fi
            fi
            ;;

        start_server)
            # 1) start_server start >>> start_server start
            # 2) start_server complete 0 >>> start_server end (normal)
            # 3) start_server complete 1 >>> start_server end (abnormal)
            if [[ $2 == "start" ]]; then
                getMessage "WDH021I"
            else
                case $3 in
                    0) getMessage "WDH022I" ;;
                    1) getMessage "WDH023C" ;;
                    *) ;;
                esac
            fi
            ;;

        stop_server)
            # 1) stop_server start >>> stop_server start
            # 2) stop_server complete 0 >>> stop_server end (normal)
            # 3) stop_server complete 1 >>> stop_server end (abnormal)
            if [[ $2 == "start" ]]; then
                getMessage "WDH031I"
            else
                case $3 in
                    0) getMessage "WDH032I" ;;
                    1) getMessage "WDH033C" ;;
                    *) ;;
                esac
            fi
            ;;

        network_up)
            # 1) network_up complete * localnode ether1  >>> ehter network up		#
            # 2) network_up complete * localnode serial1 >>> serial network up		#
            if [[ $2 == "complete" ]]; then
                case "$4:$5" in
                    ${LOCAL}:ether1) getMessage "WDH041I" ;;
                    *) ;;
                esac
            fi
            ;;

        network_down)
            # 1) network_down start localnode ether1 >>> ether network down
            # 2) network_down start -1 ether1  >>> global network down
            # 3) network_down start -1 serial1 >>> serial network down
            if [[ $2 == "start" ]]; then
                case "$3:$4" in
                    ${LOCAL}:ether1) getMessage "WDH042C" ;;
                    "-1:ether1") getMessage "WDH045C" ;;
                    *) ;;
                esac
            fi
            ;;
    esac
    
    [[ "${message}" != "PowerHA Event" ]] && {
        logWriter ${LOGFILE} "${message}"
    }
}

# ==============================================================================
# ���C������
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkClusterEvent "$@"

exit 0

