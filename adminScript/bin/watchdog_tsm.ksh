#!/bin/ksh
################################################################################
# 機能概要      : 運用監視 for TSM
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
TARGET_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst           # 監視対象リストファイル名
MW_NAME="TSM"
TSM_USR=${G_TSM_USR:=admin}
DSMADMC="dsmadmc -id=$TSM_USR"
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
    :
}

# ------------------------------------------------------------------------------
# スクリプト初期化
# ------------------------------------------------------------------------------
initializer() {
    getMessage "000001I";logWriter ${LOGFILE} "${message}"
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME}"

    getPassword ${HOSTNAME} ${TSM_USR}
    DSMADMC="${DSMADMC} -password=${PASSWORD}"
}

# ------------------------------------------------------------------------------
# TSM接続確認
# ------------------------------------------------------------------------------
watchTSMConnect() {
    ${DSMADMC} quit > /dev/null 2>&1; RC=$?
    if [[ $RC -eq  0 ]]; then
        getMessage "WD0011I";logWriter ${LOGFILE} "TSM Server ${message}"
    else
        # 接続出来ない場合は即終了とする。
        getMessage "WD0011C";logWriter ${LOGFILE} "TSM Server ${message}"
        finalizer
        exit $RC
    fi
}

# ------------------------------------------------------------------------------
# TSMメディア状態確認
# ------------------------------------------------------------------------------
watchTSMVolStatus() {

    VOL_LIST=$(${DSMADMC} q vol access=unav,des | awk '$3=="'$G_TSM_DEV'" { print $1 }')
    for vol in ${VOL_LIST}
    do
        getMessage "WD0401C";logWriter ${LOGFILE} "${vol} ${message}"; RC=99
    done
}

# ------------------------------------------------------------------------------
# TSMストレージプール使用率確認
# ------------------------------------------------------------------------------
watchTSMPoolUsage() {
    WATCH_KIND="TSM_STGPOOL"

    cat ${TARGET_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'"){print $3,$4,$5}}'|sed 's/\%//g'|while read targets limit_w limit_c
    do
        if [[ "${stgpools}" = "" ]]; then
            targets=$(${DSMADMC} query stgpool | grep "Primary" |awk '{print $1}'|tr '\n' ',')
        fi

        for pool in $(echo "$targets" | sed "s/,/ /g")
        do
            usage_p=$(${DSMADMC} query stgpool ${pool}| grep "Primary" |awk '{print $7}')
            if [[ ${usage_p} -gt ${limit_c} ]]; then
                getMessage "WD0081C";logWriter ${LOGFILE} "$pool ${message}  ${usage_p}%"; RC=99
            elif [[ ${usage_p} -gt ${limit_w} ]]; then
                getMessage "WD0081W";logWriter ${LOGFILE} "$pool ${message}  ${usage_p}%"; RC=99
            else
                getMessage "WD0081I";logWriter ${LOGFILE} "$pool ${message}  ${usage_p}%"
            fi
        done
    done
}

# ------------------------------------------------------------------------------
# TSM空き本数確認
# ------------------------------------------------------------------------------
watchTSMScratchVol() {
    WATCH_KIND="TSM_VOLEMPTY"
    
    cat ${TARGET_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'"){print $3,$4,$5}}'|sed 's/\%//g'|while read targets limit_w limit_c
    do
        unused_vol=$(${DSMADMC} q libvolume ${G_TSM_LIB} | awk 'BEGIN { NUM=0 } { if( $1=="'$G_TSM_LIB'" && $3=="スクラッチ" ) NUM=NUM+1; } END { print NUM }')

        if [[ "$unused_vol" = "" ]]; then
            getMessage "999009W";logWriter ${LOGFILE} "TSM 空きテープ本数が取得出来ませんでした。"; RC=99
        else
            if [[ ${unused_vol} -lt ${limit_c} ]]; then
                getMessage "WD0082C";logWriter ${LOGFILE} "${message}${unused_vol}本です。"; RC=99
            elif [[ ${unused_vol} -lt ${limit_w} ]]; then
                getMessage "WD0082W";logWriter ${LOGFILE} "${message}${unused_vol}本です。"; RC=99
            else
                getMessage "WD0082I";logWriter ${LOGFILE} "${message}${unused_vol}本です。"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# TSM DB使用率
# ------------------------------------------------------------------------------
watchTSMDbUsage() {
    WATCH_KIND="TSM_DB"
    
    cat ${TARGET_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'"){print $3,$4,$5}}'|sed 's/\%//g'|while read targets limit_w limit_c
    do
        used_p=$(${DSMADMC} -displ=list "SELECT USED_PAGES,USABLE_PAGES FROM DB" |awk -F: 'BEGIN{usedpg = 0; usablepg = 0} {if($1 == "  USED_PAGES"){usedpg = $2 }; if($1 == "USABLE_PAGES"){usablepg = $2 }} END {print usedpg / usablepg * 100 }')

        if [[ "${used_p}" = "" ]]; then
            getMessage "999009W";logWriter ${LOGFILE} "TSM DB の使用率が取得出来ませんでした。"; RC=99
        else
            if [[ ${used_p} -gt ${limit_c} ]]; then
                getMessage "WD0051C";logWriter ${LOGFILE} "TSM DB ${message}${used_p}%"; RC=99
            elif [[ ${used_p} -gt ${limit_w} ]]; then
                getMessage "WD0051W";logWriter ${LOGFILE} "TSM DB ${message}${used_p}%"; RC=59
            else
                getMessage "WD0051I";logWriter ${LOGFILE} "TSM DB ${message}${used_p}%"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 終結処理
# ------------------------------------------------------------------------------
finalizer() {
    getMessage "000099I";logWriter ${LOGFILE} "${message} ${SCR_NAME} RC:$RC"
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

watchTSMConnect
watchTSMDbUsage
watchTSMScratchVol
watchTSMVolStatus
#watchTSMPoolUsage

finalizer
exit $RC
