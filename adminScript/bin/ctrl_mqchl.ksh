#!/bin/ksh
################################################################################
# 機能概要      : MQ Channel起動/停止/確認
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
    echo "Usage: $(basename $0) [start | stop | restart | status] [ MQマネージャー名 | キーワード] [ MQチャネル名 ]" 
    echo "第１引数は必須"
    echo "第２引数は任意です。対象MQマネージャー名またはキーワードを指定して下さい。"
    echo "                    指定が無い場合はキーワードとしてホスト名が指定されたとみなされ、"
    echo "                    全MQマネージャーが対象となります。"
    echo "第３引数は任意です。対象MQチャネル名を指定して下さい。"
    echo "                    指定が無い場合は対象MQマネージャの全センダーチャネルが対象となります。"
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
            unset MQCHLS
            ;;
        3)  MQMGRS="$2"
            MQCHLS="$3"
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
    if [[ "$_OBJ1" != "" ]]; then MQMUSR="$_OBJ1"; fi
    # 第２引数指定が無い場合はホスト名からMQ Manager 一覧を取得する。
    if [[ "${MQMGRS}" = "" ]]; then
        if [[ "$_OBJ2" != "" ]]; then
            MQMGRS="$_OBJ2"
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
    for mqmgr in ${MQMGRS}
    do
        # MQ Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}
        MQCHLS="${MQCHLS:-$_OBJ2}"    # 引数指定が無い場合はリストファイルの値を設定

        # MQ Manager Status 取得
        getMQMStatus ${mqmgr}
        # MQ Manager 起動状態確認
        if [[ "${mqm_status}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "$mqmgr ${message} Skipping ..."
            MQCHLS=""
            continue
        fi

        # MQ Channel 接続
        for mqchl in ${MQCHLS}
        do
            getMessage "SWC001I";logWriter ${LOGFILE} "MQ Channel ${mqchl} ${message}"
            echo "start channel(${mqchl})" | \
            su - ${MQMUSR} -c "runmqsc ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
            sleep 3
        done
        MQCHLS=""
    done

}

# ------------------------------------------------------------------------------
# 停止
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x

    MQ_EXEC_FILE=""

    # MQ Object 停止
    for mqmgr in ${MQMGRS}
    do
        # MQ Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}
        MQCHLS="${MQCHLS:-$_OBJ2}"    # MQ Channel

        # MQ Manager Status 取得
        getMQMStatus ${mqmgr}

        if [[ "${mqm_status}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "$mqmgr ${message} Skipping ..."
            MQCHLS=""
            continue
        fi

        # MQ Channel 停止
        for mqchl in ${MQCHLS}
        do
            getMessage "SWC051I";logWriter ${LOGFILE} "${mqchl} ${message}"
            echo "stop channel(${mqchl})" | \
            su - ${MQMUSR} -c "runmqsc ${mqmgr}" >> ${LOGFILE} 2>&1;RC=$?
            sleep 3
        done 
        MQCHLS=""

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
    for mqmgr in ${MQMGRS}
    do
        # MQ Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${mqmgr}
        MQCHLS="${MQCHLS:-$_OBJS2}"    # MQ Channel

        # MQ Manager Status 取得
        getMQMStatus ${mqmgr}
        if [[ "${MQM_STATUS}" = "" ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "MQ Manager ${mqmgr} ${message}"
            MQCHLS=""
            continue
        fi

        # MQ Channel Status 取得
        for mqchl in ${MQCHLS}
        do
            getCHLStatus ${mqmgr} ${mqchl}
            getMessage "999009I";logWriter ${LOGFILE} "MQ Channel $mqchl は ${CHL_STATUS:="STOP"} 状態です。"
        done 
        MQCHLS=""
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

