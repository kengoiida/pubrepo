#!/bin/ksh
################################################################################
# 機能概要      : 運用監視(CPU)
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
limit_w=80                                                  # 警告閾値の省略値
limit_c=95                                                  # 危険閾値の省略値
cputime=30                                                  # インターバル省略値

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [WARNING_LIMIT] [CRITICAL_LIMIT] [INTERVAL_SECOND]" 
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# 引数チェック
# ------------------------------------------------------------------------------
checkOptions() {
    if [[ "$1" != "" ]]; then limit_w="$1"; fi
    if [[ "$2" != "" ]]; then limit_c="$2"; fi
    if [[ "$3" != "" ]]; then cputime="$3"; fi
}

# ------------------------------------------------------------------------------
# CPU使用率監視
# ------------------------------------------------------------------------------
watchCPU() {
(( ${DBG_FLG} )) && set -x
    usage_p=$(/usr/sbin/sar ${cputime} 1 | tail -1 | awk '{print $2+$3+$4}')

    if [[ ${usage_p} -ge ${limit_c} ]]; then
        getMessage "WD0051C";logWriter ${LOGFILE} "CPU ${message}${usage_p}%"
        #nohup tprof -skeuj -r ${G_SCR_LOG_HOME}/tprof_$(hostname)_$(date +%Y%m%d%H%M%S).txt -x sleep 10 &
    elif [[ ${usage_p} -ge ${limit_w} ]]; then
        getMessage "WD0051W";logWriter ${LOGFILE} "CPU ${message}${usage_p}%"
        #nohup tprof -skeuj -r ${G_SCR_LOG_HOME}/tprof_$(hostname)_$(date +%Y%m%d%H%M%S).txt -x sleep 10 &
    fi
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"

watchCPU

exit 0
