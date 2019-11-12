#!/bin/ksh
################################################################################
# 機能概要      : クラスターイベント通知
# 実行仕様      : 通常呼び出し（PowerHAから渡される引数を読み込む）
# 読込ファイル  : ${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst
# 書込ファイル  : ${G_SCR_LOG_HOME}/${SCR_NAME}.log
# 戻り値        : 0 以外は異常終了
# 更新履歴      : YYYY/MM/DD    新規作成
################################################################################
# 外部ファイル読込・変数定義
SCR_HOME=$(dirname $0)

. ${SCR_HOME}/_common_profile.conf
. ${SCR_HOME}/${G_SCR_LIB}
. ${SCR_HOME}/${G_SCR_MW_CONF}
. ${SCR_HOME}/${G_SCR_MW_LIB}

# ローカル変数初期値セット
# SCR_HOMEグローバル値へ置き換え処理
if [[ "${SCR_HOME}" = "." ]]; then SCR_HOME=${G_SCR_HOME:=.}; fi

# スクリプト共通ローカル変数定義ブロック（基本的に全てのスクリプトで定義すべき変数群）
SCR_NAME=$(basename $0 ${G_SCR_SFX})                        # スクリプト名取得
HOSTNAME=$(hostname)                                        # ホスト名取得
MSGLIST=${G_SCR_ETC_HOME}/${G_SCR_MSG}                      # スクリプトメッセージ定義ファイル名
MSGMODE=${G_MSGMODE}                                        # メッセージ出力モード
LOGDATE=$(date +%Y%m%d)                                     # スクリプトログファイル名にタイムスタンプを含める場合使用する日付。
LOGFILE=${G_SCR_LOG_HOME}/${SCR_NAME}.log                   # スクリプトログファイル名
LOGGER_TAG=${SCR_NAME}                                      # syslog出力記録用タグ文字列
RC=0                                                        # ReturnCode Reset

# スクリプト独自ローカル変数定義ブロック（スクリプト毎に異なる定義の変数群）
LOGGER_TAG="HACMP"                                          # syslog出力記録用タグ文字列
UTL_HOME=${G_HACMP_UTL_HOME}
LOCAL="$(${UTL_HOME}/get_local_nodename)"
OTHER="$(${UTL_HOME}/clnodename | grep -v ${LOCAL})"

# ------------------------------------------------------------------------------
# 引数チェック
#   $1 : event_name
#   $2 : mode (start/complete)
#   $3 : option 1
#   $4 : option 2
#   $5 : option 3
# ------------------------------------------------------------------------------
checkClusterEvent() {
(( ${DBG_FLG} )) && set -x

    getMessage "WDH000I"    # ダミーメッセージ(priority取得)
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
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkClusterEvent "$@"

exit 0

