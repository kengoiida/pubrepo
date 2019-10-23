#!/bin/ksh
################################################################################
# 機能概要      : 運用監視
# 実行仕様      : 通常呼び出し（引数なし）
# 読込ファイル  : ${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst
# 書込ファイル  : ${G_SCR_LOG_HOME}/${SCR_NAME}.log
# 戻り値        : 0 以外は異常終了
# 更新履歴      : YYYY/MM/DD    新規作成
#################################################################################
# 外部ファイル読込・変数定義
SCR_HOME=$(dirname $0)

. ${SCR_HOME}/_common_profile.conf
. ${SCR_HOME}/${G_SCR_LIB}

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
WATCH_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst            # 監視対象リストファイル名
TARGET_RESOURCES=                                                   # 監視対象リソース
islock="false"

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [リソース種別名]"
    echo "      CPU=CPU使用率監視"
    echo "      PAGE=ページングスペース使用率監視"
    echo "      FS=ファイルシステム使用率監視"
    echo "      PROC=プロセス監視"
    echo "      PING=ネットワーク疎通監視"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# 引数チェック
# ------------------------------------------------------------------------------
checkOptions() {
(( ${DBG_FLG} )) && set -x
    case "$#" in
        0)  :
            ;;
        1)  TARGET_RESOURCES="$1"
            ;;
        *)  showHelp
            ;;
    esac

}

# ------------------------------------------------------------------------------
# スクリプト初期化
# ------------------------------------------------------------------------------
initializer() {
(( ${DBG_FLG} )) && set -x
    # 監視対象ファイル存在チェック
    checkFileExist ${WATCH_LIST}
    if [[ $RC -ne 0 ]]; then 
        exit $RC
    fi
}

# ------------------------------------------------------------------------------
# プロセス監視
# ------------------------------------------------------------------------------
watchProcess() {
(( ${DBG_FLG} )) && set -x
    # 閾値指定が無い場合は1プロセスとみなす
    if [[ "$limit_w" = "" ]]; then limit_w=1; fi
    if [[ "$limit_c" = "" ]]; then limit_c=1; fi

    for target in $(echo ${targets} | sed 's/,/ /g')
    do
        checkProcess "${target}"
        if [[ ${procs} -lt $limit_c ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "${target} ${message}"
        elif [[ ${procs} -lt ${limit_w} ]]; then
            getMessage "WD0041W";logWriter ${LOGFILE} "${target} ${message}"
        fi
    done
}

# ------------------------------------------------------------------------------
# ファイルシステム使用率監視
# ------------------------------------------------------------------------------
watchFSUsage() {
(( ${DBG_FLG} )) && set -x

    # 非監視ファイル存在チェック
    checkLckFile ${G_WDLOCK}
    if [[ $? -eq 1 ]]; then
        getMessage "WD0900I";logWriter ${LOGFILE} "FS使用率は${message}( $targets )"
        return 0
    fi

    mmode_tmp=${MSGMODE}

    for target in $(echo ${targets} | sed 's/,/ /g')
    do
        if [[ "$target" = "$(df ${target} | awk -v NAME="${target}" '$7==NAME {print $7}')" ]]; then
            usage_p=$(df ${target} | awk -v NAME="${target}" '$7==NAME {print $4}' | cut -f 1 -d%)
            if [[ ${usage_p} -gt ${limit_c} ]]; then
                getMessage "WD0061C"; checkDupMsg ${priority} "${target}"; logWriter ${LOGFILE} "${target} ${message}${usage_p}%"
            elif [[ ${usage_p} -gt ${limit_w} ]]; then
                getMessage "WD0061W"; checkDupMsg ${priority} "${target}"; logWriter ${LOGFILE} "${target} ${message}${usage_p}%"
            else
                getMessage "WD0061I"; checkDupMsg ${priority} "${target}"; logWriter ${LOGFILE} "${target} ${message}${usage_p}%"
            fi
        fi
    done

    MSGMODE=${mmode_tmp}
}

# ------------------------------------------------------------------------------
# ページング使用率監視
# ------------------------------------------------------------------------------
watchPaging() {
(( ${DBG_FLG} )) && set -x
    # 非監視ファイル存在チェック
    checkLckFile ${G_WDLOCK}
    if [[ $? -eq 1 ]]; then
        getMessage "WD0900I";logWriter ${LOGFILE} "ページング使用率は${message}"
        return 0
    fi

    usage_p=$(lsps -s|tail -1|awk '{print $2}'|sed 's/\%//g')

    if [[ ${usage_p} -gt ${limit_c} ]]; then
        getMessage "WD0071C";logWriter ${LOGFILE} "${message}${usage_p}%"
    elif [[ ${usage_p} -gt ${limit_w} ]]; then
        getMessage "WD0071W";logWriter ${LOGFILE} "${message}${usage_p}%"
    fi
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

cat ${WATCH_LIST} | egrep "^${HOSTNAME}:|^COMMON:"| egrep "$(echo ${TARGET_RESOURCES}| sed 's/,/|/g')" | while read target_line
do
    kind=$(echo ${target_line}|awk -F: '{print $2}')
    targets=$(echo ${target_line}|awk -F: '{print $3}')
    limit_w=$(echo ${target_line}|awk -F: '{print $4}'|sed 's/\%//g')
    limit_c=$(echo ${target_line}|awk -F: '{print $5}'|sed 's/\%//g')
    freevalue1=$(echo ${target_line}|awk -F: '{print $6}')
    freevalue2=$(echo ${target_line}|awk -F: '{print $7}')

    case "${kind}" in
        PROC|PROC_OS)    
            watchProcess
            ;;
        PAGE)
            watchPaging
            ;;
        FS)
            watchFSUsage
            ;;
        CPU)
            # バックグラウンド投入
            ${SCR_HOME}/${SCR_NAME}_cpu${G_SCR_SFX} ${limit_w} ${limit_c} ${freevalue1} >/dev/null 2>&1 &
            ;;
        PING)
            # バックグラウンド投入
            ${SCR_HOME}/${SCR_NAME}_ping${G_SCR_SFX} ${targets} >/dev/null 2>&1 &
            ;;
        *)  
            :
            ;;
    esac

done

exit 0
