#!/bin/ksh
################################################################################
# 機能概要      : 運用監視
# 実行仕様      : 通常呼び出し（引数なし）
# 読込ファイル  : ${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst
# 書込ファイル  : ${G_SCR_LOG_HOME}/${SCR_NAME}.log
# 戻り値        : 0 以外は異常終了
# 更新履歴      : YYYY/MM/DD    新規作成
################################################################################
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
WATCH_LIST=${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst         # 監視対象リストファイル名
TARGETS=

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [ホスト名]"
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
        1)  TARGETS="$1"
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
}

# ------------------------------------------------------------------------------
# ping監視
# ------------------------------------------------------------------------------
watchPing() {
(( ${DBG_FLG} )) && set -x
    ping -5 "$1"
    if [[ $? -ne 0 ]]; then 
        getMessage "WD0021C";logWriter ${LOGFILE} "$1 $2 ${message}"
    fi
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

if [[ "TARGETS" = "" ]]; then
    # 監視対象ファイル存在チェック
    checkFileExist ${WATCH_LIST}
    if [[ $RC -ne 0 ]]; then exit 0; fi
    
    cat ${WATCH_LIST} | egrep -v "^#|^$|^ " | while read ip name
    do
        watchPing "${ip}" "${name}"
    done
else
    for ip in $(echo "${TARGETS}" | sed 's/,/ /g')
    do
        watchPing "${ip}" "-"
    done

fi

exit 0
