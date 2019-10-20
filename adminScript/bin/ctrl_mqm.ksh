#!/bin/ksh
################################################################################
# 機能概要      : MQ Manager起動/停止/確認
# 実行仕様      : 引数指定を伴った通常呼び出し
# 読込ファイル  : 共通外部定義ファイル
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
MW_NAME="MQM"
MQMUSR="mqm"        # MQ Manager User Default
MQMGRS=             # MQ Manager
MQLSNP=             # MQ Listner Port No
MQCHLS=             # MQ Channel
MQQUES=             # MQ Queue

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | restart | status] [MQマネージャー名]" 
    echo "第１引数は必須"
    echo "第２引数はMQマネージャー名を指定して下さい(任意) 。指定が無い場合は登録リストを参照します。"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# 引数チェック
# ------------------------------------------------------------------------------
checkOptions() {
    option="$1"

    case "$#" in
        1)  :
            ;;
        2)  MQMGRS="$2"
            ;;
        *)  showHelp
            ;;
    esac
}

# ------------------------------------------------------------------------------
# スクリプト初期化
# ------------------------------------------------------------------------------
initializer() {
    getMessage "000001I";logWriter ${LOGFILE} "${message}"
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} ${MQMGRS}"

    getObject ${HOSTNAME} ${MW_NAME}
    if [[ "$_OBJ2" != "" ]]; then MQMUSR="$_OBJ2"; fi
    # 第２引数指定が無い場合は登録リストからMQ Manager 一覧を取得する。
    if [[ "${MQMGRS}" = "" ]]; then
        if [[ "$_OBJ1" != "" ]]; then
            MQMGRS="$_OBJ1"
        else
            # 登録リストでも確認出来ない場合mqs.iniから取得する。
            getMQMInfo "$_OBJ3"
        fi
    fi    
}

# ------------------------------------------------------------------------------
# 起動
# ------------------------------------------------------------------------------
doStart() {
(( ${DBG_FLG} )) && set -x

    # MQ Object 起動
    for mqmgr in $(echo "${MQMGRS}" | sed "s/,/ /g")
    do
        # MQ Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}

        # MQ Manager Status 取得
        getMQMStatus ${mqmgr}
        if [[ "${mqm_status}" != "" ]]; then
            getMessage "SWC009W";logWriter ${LOGFILE} "${mqmgr} ${message}"
            continue
        fi

        su - ${MQMUSR} -c "strmqm ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        if [[ $RC != 0 ]]; then
            getMessage "SWC002C";logWriter ${LOGFILE} "${mqmgr} ${message} RC=$RC"
            exit 99
        fi

        # Command Server 起動
        #su - ${MQMUSR} -c "strmqcsv ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        #if [[ $RC != 0 ]]; then
        #    getMessage "SWC002C";logWriter ${LOGFILE} "Command Server ${message} RC=$RC"
        #    exit 99
        #fi

        getMessage "SWC002I";logWriter ${LOGFILE} "${mqmgr} ${message}"

    done

}

# ------------------------------------------------------------------------------
# 停止
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x

    MQ_EXEC_FILE=""

    # MQ Object 停止
    for mqmgr in $(echo "${MQMGRS}" | sed "s/,/ /g")
    do
        # MQ Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}

        # MQ Manager Status 確認
        getMQMStatus ${mqmgr}
        if [[ "${MQM_STATUS}" = "" ]]; then
            getMessage "SWC059W";logWriter ${LOGFILE} "$mqmgr ${message}"
            continue
        fi

        # Command Server 停止
        #su - ${MQMUSR} -c "endmqcsv -i ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        #getMessage "SWC052I";logWriter ${LOGFILE} "Command Server ${message} RC=$RC"

        # MQ Manager 停止
        su - ${MQMUSR} -c "endmqm -i ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
        if [[ $RC != 0 ]]; then
            getMessage "SWC052C";logWriter ${LOGFILE} "${mqmgr} ${message} RC=$RC"; return
        fi
        getMessage "SWC052I";logWriter ${LOGFILE} "${mqmgr} ${message}"
    done
}

# ------------------------------------------------------------------------------
# 再起動
# ------------------------------------------------------------------------------
doRestart() {
    :
}

# ------------------------------------------------------------------------------
# MQ Object Status 取得
# ------------------------------------------------------------------------------
getStatus() {
(( ${DBG_FLG} )) && set -x

    # MQ Object Status 取得
    for mqmgr in $(echo "${MQMGRS}" | sed "s/,/ /g")
    do
        # MQ Manager Status 取得
        getMQMStatus ${mqmgr}
        if [[ "${MQM_STATUS}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "MQ Manager ${mqmgr} ${message}"
        else
            getMessage "WD0041I";logWriter ${LOGFILE} "MQ Manager ${mqmgr} ${message}"
        fi
    done
}

# ------------------------------------------------------------------------------
# スクリプト終結処理
# ------------------------------------------------------------------------------
finalizer() {
    getMessage "000099I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} RC=${RC}"
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

case "${option}" in
    start)
        doStart
        ;;
    stop)
        doStop
        ;;
    restart)
        doRestart
        ;;
    status)
        getStatus
        ;;
    *)
        showHelp
        ;;
esac

finalizer

exit 0

