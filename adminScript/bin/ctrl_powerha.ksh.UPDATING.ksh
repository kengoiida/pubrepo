#!/bin/ksh
################################################################################
# 機能概要      : PowerHA 起動/停止/稼働状況表示
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
#MW_NAME=HACMP
MW_NAME=PowerHA
NODES=
HACMP_GROUP_STATUS=
HACMP_CURRENT_STATUS=
HACMP_NODE_STATUS=
SERVICE=CIS-PSV-PHA
# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [start | stop | graceful | takeover | force | status] [ノード一覧]"
    echo "第１引数は必須"
    echo "第２引数は任意です。"
    echo "ノード名が複数ある場合はカンマ区切りで指定して下さい。"

    getMessage "H00002I";echo "${priority} ${message}"
    exit 0
}

# ------------------------------------------------------------------------------
# 引数チェック
# ------------------------------------------------------------------------------
checkOptions() {
    option="$1"

    case "$#" in
        1)  :
            ;;
        2)  NODES="$2"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME} ${option} ${NODES}"
    
    if [[ "${NODES}" = "" ]]; then
        NODES=$(${G_HACMP_UTL_HOME}/get_local_nodename)
        #getMessage "999009I";logWriter ${LOGFILE} "ノード名指定が無いため自動取得を行いました。NODE=$NODES"
        if [[ "${NODES}" = "" ]]; then
            getMessage "999009W";logWriter ${LOGFILE} "ノード名が存在しないため処理を中止します。"
            exit 99
        fi
    fi
}

# ------------------------------------------------------------------------------
# 起動
# ------------------------------------------------------------------------------
doStart() {
    getMessage "SWC001I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
    
    # 稼働状況確認
    getStatus >> /dev/null
    if [[ "${HACMP_CURRENT_STATUS}" != "ST_INIT" ]]; then
        getMessage "SWC009I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
    else
        _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_rc.cluster -N -cspoc-n "${NODES}" -A -C yes>> ${LOGFILE} 2>&1;RC=$?

        # -N : 即座にデーモン (inittab の変更なし) を始動します。
        # -cspoc-n : ノード・リストの指定
        # -b : 始動をブロードキャストします。
        # -i : クラスター情報 ( clinfoES ) デーモンを、デフォルト・オプションで始動します。
        # -C : デフォルト:interactive   エラーを自動で訂正する:yes
        # -A : リソースグループの管理を自動で行う


        # 結果判定
        if [[ $RC -eq 0 ]]; then
            getMessage "SWC002I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
        else
            getMessage "SWC002C";logWriter ${LOGFILE} "${MW_NAME} ${message}"
            # exit 99
        fi
    fi
}

# ------------------------------------------------------------------------------
# 通常停止
# ------------------------------------------------------------------------------
doGraceful() {
    getMessage "SWC051I";logWriter ${LOGFILE} "${option} オプションで ${MW_NAME} ${message}"

    # 起動状態確認
    getStatus >> /dev/null
    if [[ "${HACMP_CURRENT_STATUS}" != "ST_STABLE" ]]; then
        getMessage "SWC059I";logWriter ${LOGFILE} "${MW_NAME} ${message} STATUS=${HACMP_CURRENT_STATUS}"
    else
        _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_clstop -N -cspoc-n "${NODES}" -s -g >> ${LOGFILE} 2>&1; RC=$?

        # -N  : 即時にシャットダウンします。
        # -cspoc-n : ノード・リストの指定
        # -s  : サイレント・シャットダウン。シャットダウン・メッセージを /bin/wall  を介してブロードキャスト しないように  指定します。デフォルトでは、ブロードキャストが行われます。
        # -g  : クラスター・サービスが停止され、リソース・グループはオフラインになります。リソースは解放 されません 。
        # -gr : クラスター・サービスが停止され、リソース・グループは次のノードに引き継がれます。


        # 結果判定
        if [[ $RC -eq 0 ]]; then
            getMessage "SWC052I";logWriter ${LOGFILE} "${MW_NAME} ${message}"
        else
            getMessage "SWC052C";logWriter ${LOGFILE} "${MW_NAME} ${message} RC=$RC"
            # exit 99
        fi
    fi
}

# ------------------------------------------------------------------------------
# テイクオーバー
# ------------------------------------------------------------------------------
doTakeover() {
    getMessage "SWC051I";logWriter ${LOGFILE} "${option} オプションで ${MW_NAME} ${message}"
    _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_clstop '-N' -cspoc-n ${NODES} '-s' '-gr' >> ${LOGFILE} 2>&1;RC=$?

    # 結果判定
    if [[ $RC -ne 0 ]]; then
        getMessage "SWC061I";logWriter ${LOGFILE} "${MW_NAME} ${message} RC=$RC"
        # exit 99
    fi
    
}

# ------------------------------------------------------------------------------
# 強制停止
# ------------------------------------------------------------------------------
doForce() {
    getMessage "SWC051I";logWriter ${LOGFILE} "${option} オプションで ${MW_NAME} ${message}"
    
    _SPOC_FORCE=Y /usr/es/sbin/cluster/cspoc/fix_args nop cl_clstop '-N' -cspoc-n ${NODES} '-s' '-f' >> ${LOGFILE} 2>&1;RC=$?
    
    # 結果判定
    if [[ $RC -ne 0 ]]; then
        getMessage "SWC061I";logWriter ${LOGFILE} "${MW_NAME} ${message} RC=$RC"
        # exit 99
    fi
}

# ------------------------------------------------------------------------------
# ステータス確認
# ------------------------------------------------------------------------------
getStatus() {
    MSGMODE=""
    ${G_HACMP_UTL_HOME}/clcheck_server cthags > /dev/null 2>&1; RC=$?
    if [[ $RC -ne 0 ]]; then
        #${G_HACMP_UTL_HOME}/cllssvcs > /dev/null 2>&1; RC=$?
        netstat -i | grep -w ${SERVICE} > /dev/null 2>&1; RC=$?
        if [[ $RC -eq 0 ]]; then
            HACMP_NODE_STATUS="Service"
            getMessage "SWC019I";logWriter ${LOGFILE} "${HOSTNAME} は PowerHA Service Node として活動中です。"
        else
            HACMP_NODE_STATUS="Stanby"
            getMessage "SWC019I";logWriter ${LOGFILE} "${HOSTNAME} は PowerHA Stanby Node として活動中です。"
        fi
    else
        getMessage "SWC059I";logWriter ${LOGFILE} "PowerHA ${message}"
    fi
    
    HACMP_CURRENT_STATUS=$(export LANG=C; lssrc -ls clstrmgrES  | grep "Current state:" | awk '{print $3}')
    getMessage "999009I";logWriter ${LOGFILE} "PowerHA CURRENT STATUS=${HACMP_CURRENT_STATUS}"
    #echo "ST_INIT=停止状態   ST_RP_RUNNING=起動途中   ST_STABLE=起動完了でステーブル状態   ST_BARRIER=イベント障害中？  ST_RP_FAILED=イベントスクリプトが失敗しているなど"
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
    stop|graceful)
        doGraceful
        ;;
    takeover)
        doTakeover
        ;;
    force)
        doForce
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

