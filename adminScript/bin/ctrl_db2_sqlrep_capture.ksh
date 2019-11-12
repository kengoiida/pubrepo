#!/bin/ksh
################################################################################
# 機能概要      : SQL Replication Capture Program 起動/停止/確認
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
MW_NAME="SQLCAP"

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | restart | status] [DB名] [cold | warmsi | warmns]"
    echo "引数1:制御種別を指定して下さい。"
    echo "引数2:キャプチャーサーバー名（データベース名）を指定して下さい。"
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
        2)  REP_SVRS="$2"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option}"
    
    # 第２引数指定が無い場合は登録リストからサーバー(DB)一覧を取得する。
    if [[ "${REP_SVRS}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVRS="$_OBJ1"
    fi

}

# ------------------------------------------------------------------------------
# 起動
# ------------------------------------------------------------------------------
doStart() {
(( ${DBG_FLG} )) && set -x

    getMessage "SWC001I";logWriter ${LOGFILE} "CAPTURE PROGRAM ${message}"

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do

        # SQL-REP CAPTURE 情報取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"
        _schema="$_OBJ2"
        _path="$_OBJ4"

        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            su - "${_user}" -c "nohup asncap capture_server=${svr} capture_schema=${_schema} capture_path=${_path} autostop=n commit_interval=30 logreuse=n startmode=warmsi &" >> ${LOGFILE} 2>&1;_rc=$?
            if [[ $_rc -ne  0 ]]; then
                RC=$(($RC+$_rc)); getMessage "SWC002C";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} RC=$RC"
            else
                getMessage "SWC002I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
            fi
            sleep 5
        else
            getMessage "SWC009I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
        fi

    done

    if [[ $RC -ne  0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${REP_SVRS} ${message}"; fi
}

# ------------------------------------------------------------------------------
# 停止
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x

    getMessage "SWC051I";logWriter ${LOGFILE} "Capture Program ${message}"

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do

        # SQL-REP CAPTURE 情報取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"
        _schema="$_OBJ2"
        _path="$_OBJ4"

        checkProcess ${MW_NAME} "${svr}"
        if [[ ${procs} -ne 0 ]]; then
            su - "${_user}" -c "asnccmd capture_schema=${_schema} capture_server=${svr} stop" >>${LOGFILE} 2>&1;RC=$?
            if [[ $RC -ne  0 ]]; then
                getMessage "SWC052C";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} RC=$RC"
                exit 99
            fi
        else
            getMessage "SWC059I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
            continue
        fi

        for i in 1 2 3 4 5 6 7 8 9 10; do
            sleep 2
            checkProcess ${MW_NAME} "${svr}"
            if [[ "${procid}" = "" ]]; then
                getMessage "SWC052I";logWriter ${LOGFILE} "${CAP_SVR} CAPTURE PROGRAM ${message}"
                break
            else
                if [ $i -ge 10 ]; then getMessage "SWC052C";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} PRC-ID=${procid}";exit 99; fi
            fi
        done
    done
}

# ------------------------------------------------------------------------------
# 再起動
# ------------------------------------------------------------------------------
doRestart() {
    :
}

# ------------------------------------------------------------------------------
# ステータス確認
# ------------------------------------------------------------------------------
getStatus() {
(( ${DBG_FLG} )) && set -x

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        checkProcess ${MW_NAME} "${svr}"
        if [[ ${procs} -ne 0 ]]; then
            getMessage "SWC009I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message} PROC-ID=${procid}"
        else
            getMessage "SWC059I";logWriter ${LOGFILE} "${svr} CAPTURE PROGRAM ${message}"
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
