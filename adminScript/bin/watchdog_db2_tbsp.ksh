#!/bin/ksh
################################################################################
# 機能概要      : 運用監視 for DB2
# 実行仕様      : 通常呼び出し（引数なし）
# 読込ファイル  : ${G_SCR_ETC_HOME}/watchdog_target.lst
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
MW_NAME="DB2"
WATCH_KIND="DB2_TBSP"
INSTANCES=
DBNAMES=
PASSWORD=

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo "Usage: $(basename $0) [インスタンス名]"
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
        1)  INSTANCES="$1"
            ;;
        *)  showHelp
            ;;
    esac

    # 監視対象ファイル存在チェック
    checkFileExist ${TARGET_LIST}; RC=$?
    if [[ $RC -ne 0 ]]; then 
        exit $RC
    fi

}

# ------------------------------------------------------------------------------
# スクリプト初期化
# ------------------------------------------------------------------------------
initializer() {

    # 非監視ファイル存在チェック
    checkLckFile ${G_WDLOCK}
    if [[ $? -eq 1 ]]; then
        exit 0
    fi

    # 共通変数および第１引数指定が無い場合はホスト名をキーワードにOBJECTリストからINSTANCE 一覧を取得する。
    if [[ "${INSTANCES}" = "" ]]; then
        # DB2 Instance 取得
        getObject ${HOSTNAME} ${MW_NAME}
        INSTANCES=$_OBJS1
    fi

}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

checkOptions "$@"
initializer

cat ${TARGET_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'" ) {print $3,$4,$5,$6}}'  |sed 's/\%//g' | read tbsp limit_w limit_c dbname
do

done






for inst in $(echo "${INSTANCES}" | sed "s/,/ /g")
do
    cat ${TARGET_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'" && $3 == "'$inst'" ) {print $3}}' | read wdtarget
    if [[ "$wdtarget" = "" ]]; then
        continue
    else
        cat ${TARGET_LIST} |egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$WATCH_KIND'" && $3 == "'$inst'" ) {print $4,$5,$6}}'  |sed 's/\%//g' | read target limit_w limit_c
    fi

    # INSTANCE情報取得
    getInstInfo ${inst}     # DBNAMES取得

    # PWD取得
    getPassword ${HOSTNAME} ${inst}

    for dbname in $(echo ${DBNAMES} | sed 's/,/ /g')
    do
        # DB接続確認
        checkDB2Conn ${dbname} ${inst} ${PASSWORD}; RC=$?
        if [[ $RC != 0 ]]; then
            getMessage "WD0011C";logWriter ${LOGFILE} "${inst} ${message}"; continue
        fi


        watchDB2TableSpaceUsage ${dbname}
        su - "${inst}" -c "db2 +o terminate"

    done
done

exit 0
