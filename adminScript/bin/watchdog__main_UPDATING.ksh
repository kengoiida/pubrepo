#!/bin/ksh
################################################################################
# 機能概要      : 運用監視
# 実行仕様      : 引数指定を伴った通常呼び出し
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
RC=0                                                        # リターンコードリセット
NODENAME=                                                   # HAMCPノード名

# スクリプト独自ローカル変数定義ブロック（スクリプト毎に異なる定義の変数群）
WATCH_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst            # 監視対象リストファイル名
LOGFILE=${G_SCR_LOG_HOME}/monitor.log                       # スクリプトログファイル名
islock="false"
EXCLUDE_LIST=${G_SCR_ETC_HOME}/${SCR_NAME}_exclude.lst
EXEC_SCRIPTS=

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0)"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# 引数チェック
# ------------------------------------------------------------------------------
checkOptions() {
    case "$#" in
        1)  EXEC_SCRIPTS="$1"
            ;;
        *)  showHelp
            ;;
    esac
    
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"

# HACMP Object 取得(リソースグループ)
getObject ${HOSTNAME} "HACMP" ${HOSTNAME}
RGPS=${_OBJS3}

# HACMP ノード名取得
case ${HOSTNAME} in
    "CIS-PSV-ORD") NODENAME="CIS_PSV_ORD" 
        ;;
    "CIS-PSV-STB") NODENAME="CIS_PSV_STB" 
        ;;
    *)
        ;;
esac

for exec_script in $(echo ${EXEC_SCRIPTS} | sed 's/,/ /g')
do
    if [[ "${RGPS}" = "" ]]; then
        [[ -f ${SCR_HOME}/${exec_script} ]] && ${SCR_HOME}/${exec_script}
    else
        for rgp in ${RGPS}
        do
            rgp_status=$(LANG=C  /usr/es/sbin/cluster/utilities/clRGinfo -s | awk -F: '{ if($1 == "'${rgp}'" && $3 == "'${NODENAME}'") {print $2}}')

            if [[ "${rgp_status}" = "ONLINE" ]]; then
                [[ -f ${SCR_HOME}/${exec_script} ]] && ${SCR_HOME}/${exec_script}
            fi
        done
    fi
done

exit 0
