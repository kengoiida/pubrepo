#!/bin/ksh
################################################################################
# 機能概要      : 運用監視 for SQL-Replication
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
WATCH_LIST=${G_SCR_ETC_HOME}/watchdog_target.lst            # 監視対象リストファイル名
OBJECT_LIST=${G_SCR_ETC_HOME}/${G_SCR_MW_OBJECT}            # ミドルウェアオブジェクトリストファイル名
MW_NAME="SQLREP"
DB2_PROFILE=~/sqllib/db2profile
PASSWORD=
QRPRCS=
REP_SVR=
exclude_list=''
# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [ データベース名 ]"
    echo "第１引数は任意です。指定が無い場合は登録リストがチェックされます。"
    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# 引数チェック
# ------------------------------------------------------------------------------
checkOptions() {
    case "$#" in
        0)  :
            ;;
        1)  REP_SVRS="$1"
            ;;
        *)  showHelp
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Caputure Server Status確認
# ------------------------------------------------------------------------------
watchCAPStatus() {
(( ${DBG_FLG} )) && set -x
    
    MW_NAME="SQLCAP"
    
    # 第１引数指定が無い場合は登録リストからレプリケーションプロセス一覧を取得する。
    if [[ "${REP_SVRS}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVRS="$_OBJS1"   # キャプチャーサーバー一覧
        if [[ "${REP_SVRS}" = "" ]]; then return; fi
    fi

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        cat ${WATCH_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'$svr'" ) {print $3}}' | read wdtarget

        if [[ "$wdtarget" = "" ]]; then
            getMessage "WD0999I";logWriter ${LOGFILE} "SQL-Rep Capture Server ${svr} は監視対象ではありません。"; continue
        fi

        # SQL-repプロセス確認
        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "SQL-Rep Caputure Server ${svr} ${message}"
        fi

    done
}

# ------------------------------------------------------------------------------
# Apply Server Status確認
# ------------------------------------------------------------------------------
watchAPPStatus() {
(( ${DBG_FLG} )) && set -x

    MW_NAME="SQLAPP"

    # 第１引数指定が無い場合はホスト名からレプリケーションプロセス一覧を取得する。
    if [[ "${REP_SVRS}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVRS=$_OBJS1     # アプライプロセス一覧 取得
        if [[ "${REP_SVRS}" = "" ]]; then return; fi
    fi    

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        cat ${WATCH_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'$svr'" ) {print $3}}' | read wdtarget

        if [[ "$wdtarget" = "" ]]; then
            getMessage "WD0999I";logWriter ${LOGFILE} "SQL-Rep Apply Server ${svr} は監視対象ではありません。"; continue
        fi

        # Rep Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"
        _schema="$_OBJ2"
        _path="$_OBJ4"

        # サブスクリプションステータス確認
        if [[ "${G_SQLCAP_TBL_SUBSET}" != "" ]]; then
            tmp_sql="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_SQLCAP_TBL_SUBSET}.sql"
            tmp_sub="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_SQLCAP_TBL_SUBSET}.tmp"
            echo "connect to ${svr};" > ${tmp_sql}
            echo "select count(*) from ${_schema}.${G_SQLCAP_TBL_SUBSET} where member_state = 'D';" >> ${tmp_sql}
            echo "terminate;" >> ${tmp_sql}
            su - ${_user} -c "db2 -tvf ${tmp_sql}" > ${TMP_LIST}
            noact=$(cat ${TMP_LIST}|awk '/^select/ { getline; print }' | sed 's/ //g')
            if [[ ${noact} -ne 0 ]]; then
                getMessage "999009W";logWriter ${LOGFILE} "SQL-Rep [${_user}] 非活動状態のサブスクリプションが ${noact}件あります。"
                RC=3
            fi
        fi

    done
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"

watchCAPStatus
watchAPPStatus

exit 0

