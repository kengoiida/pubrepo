#!/bin/ksh
###################################################################################
# 機能概要      : DB2 起動/停止/確認
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
MW_NAME="DB2"
INSTANCES=
INSTHOME=
DBNAMES=
PASSWORD=
# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | stopforce | stopkill | restart | status] [インスタンス名]"
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
        2)  INSTANCES="$2"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} ${INSTANCES}"

    # 第２引数指定が無い場合はホスト名をキーワードにOBJECTリストからINSTANCE 一覧を取得する。
    if [[ "${INSTANCES}" = "" ]]; then
        # DB2 Instance 取得
        getObject ${HOSTNAME} ${MW_NAME}
        INSTANCES="$_OBJ1"
    fi
}

# ------------------------------------------------------------------------------
# 起動
# ------------------------------------------------------------------------------
doStart() {
(( ${DBG_FLG} )) && set -x
    for inst in $(echo "${INSTANCES}" | sed "s/,/ /g")
    do
        getMessage "SWC001I";logWriter ${LOGFILE} "${inst} ${message}"

        # INSTANCE情報取得
        getInstInfo ${inst}
        
        #echo "0 ${HOSTNAME} 0" >  ${INSTHOME}/sqllib/db2nodes.cfg
        # INSTANCE稼動確認
        checkProcess ${MW_NAME} ${inst}
        if [[ ${procs} -eq 0 ]]; then

            # INSTANCE起動
            su - "${inst}" -c "db2start" >> ${LOGFILE} 2>&1; _rc=$?
            if [[ $_rc -eq  0 ]]; then
                #doActivate
                getMessage "SWC002I";logWriter ${LOGFILE} "${inst} ${message}"
            else
                RC=$(($RC+$_rc)); getMessage "SWC002C";logWriter ${LOGFILE} "${inst} ${message} RC=$RC"
            fi
        else
            getMessage "SWC009I";logWriter ${LOGFILE} "${inst} ${message}"
        fi
    done

    if [[ $RC -ne  0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${INSTANCES} ${message}"; fi

}

# ------------------------------------------------------------------------------
# DB活動化
# ------------------------------------------------------------------------------
doActivate() {
(( ${DBG_FLG} )) && set -x
    for dbname in $(echo "${DBNAMES}" | sed "s/,/ /g")
    do
        su - "${inst}" -c "db2 activate database ${dbname}" >> ${LOGFILE} 2>&1; _rc=$?
        if [[ $_rc -eq  0 ]]; then
            getMessage "SWC012I";logWriter ${LOGFILE} "${dbname} ${message}"
        else
            RC=$(($RC+$_rc)); getMessage "SWC012C";logWriter ${LOGFILE} "${dbname} ${message} RC=$RC"
        fi
    done

    if [[ $RC -ne  0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${DBNAMES} ${message}"; fi
}

# ------------------------------------------------------------------------------
# 停止
# ------------------------------------------------------------------------------
doStop() {
(( ${DBG_FLG} )) && set -x
    for inst in $(echo "${INSTANCES}" | sed "s/,/ /g")
    do

        # INSTANCE情報取得
        getInstInfo ${inst}

        getMessage "SWC051I";logWriter ${LOGFILE} "${inst} ${message}"
        
        checkProcess ${MW_NAME} ${inst}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "SWC059W";logWriter ${LOGFILE} "${inst} ${message}"
        else
            case "${option}" in
                stop)
                    for try in 1 2
                    do
                        sleep 1
                        su - "${inst}" -c "db2 -v force application all" >> ${LOGFILE} 2>&1; _rc=$?
                    done

                    su - "${inst}" -c "db2stop" >> ${LOGFILE} 2>&1; _rc=$?
                    ;;
                stopforce)
                    su - "${inst}" -c "db2stop force" >> ${LOGFILE} 2>&1; _rc=$?
                    ;;
                stopkill)
                    su - "${inst}" -c "db2kill" >> ${LOGFILE} 2>&1; _rc=$?
                    ;;
                *)
                    showHelp
                    ;;
            esac

            if [[ $_rc -eq  0 ]]; then
                getMessage "SWC052I";logWriter ${LOGFILE} "${inst} ${message}"
            else
                RC=$(($RC+$_rc)); getMessage "SWC052C";logWriter ${LOGFILE} "${inst} ${message} RC=$RC"
            fi
        fi

    done
            
    if [[ $RC -ne 0 ]]; then getMessage "SWC099W";logWriter ${LOGFILE} "${INSTANCES} ${message}"; fi
}

# ------------------------------------------------------------------------------
# 再起動
# ------------------------------------------------------------------------------
doRestart() {
(( ${DBG_FLG} )) && set -x
    option="stop"; doStop; option="restart"; sleep 5; doStart
}

# ------------------------------------------------------------------------------
# ステータス確認
# ------------------------------------------------------------------------------
getStatus() {
(( ${DBG_FLG} )) && set -x

    MSGMODE=""

    for inst in ${INSTANCES}
    do

        # INSTANCE情報取得
        getInstInfo ${inst}

        # PWD取得
        getPassword ${HOSTNAME} ${inst}

        # プロセスチェック
        checkProcess ${MW_NAME} ${inst}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "SWC059I";logWriter ${LOGFILE} "${inst} ${message}"; _rc=$?; RC=$(($RC+$_rc))
        else 
            getMessage "WD0041I";logWriter ${LOGFILE} "${inst} ${message}"
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
    stop|stopforce|stopkill)
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

exit $RC
