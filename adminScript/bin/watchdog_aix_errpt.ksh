#!/bin/ksh
################################################################################
# 機能概要      : errpt情報からsyslogへ書き出しを行う
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
EXCLUDE_LIST=${G_SCR_ETC_HOME}/${SCR_NAME}_exclude.lst      # errptメッセージ除外リスト
LOGGER_TAG=errpt                                            # syslog出力記録用タグ文字列

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
showHelp() {
    getMessage "H00001I";echo "${message}"
    echo " "
    echo '$1:エラー・ログ・エントリーからのシーケンス番号'
    echo '$2:エラー・ログ・エントリーからのエラー ID'
    echo '$3:エラー・ログ・エントリーからのクラス (H,S,O,U)'
    echo '$4:エラー・ログ・エントリーからのタイプ (INFO,PEND,PERM,PERF,TEMP,UNKN)'
    # echo '$5:エラー・ログ・エントリーからの警報フラグ値'
    echo '$6:エラー・ログ・エントリーからのリソース名'
    # echo '$7:エラー・ログ・エントリーからのリソース・タイプ'
    # echo '$8:エラー・ログ・エントリーからのリソース・クラス'
    # echo '$9:エラー・ログ・エントリーからのエラー・ラベル'
    echo " "

    getMessage "H00002I";echo "${priority} ${message}"
    exit 1
}

# ------------------------------------------------------------------------------
# 除外リストチェック
# ------------------------------------------------------------------------------
checkExcludeList() {
    # 除外リストから一致する行数を取得。
    if [[ -s ${EXCLUDE_LIST} ]]; then
        #out_flag=$(cat ${EXCLUDE_LIST} | grep -v ^"#" | grep "$errpt_id" | awk '{ if($1 == "'$errpt_id'" && $4 == "'$errpt_class'" ) {print $0}}' | wc -l | sed "s/ //g")
        out_flag=$(cat ${EXCLUDE_LIST} | grep -v ^"#" | grep "$errpt_id" | awk '{ if($1 == "'$errpt_id'" ) {print $0}}' | wc -l | sed "s/ //g")
    else
        # getMessage "999009I";logWriter ${LOGFILE} "除外リスト ${EXCLUDE_LIST} の定義が存在しないようです。"
        :
    fi
}

# ------------------------------------------------------------------------------
# エラークラスチェック
# ------------------------------------------------------------------------------
checkErrorClass() {
    case "${errpt_class}" in
        H)
            class_name="HARD_WARE"
            ;;
        S)
            class_name="SOFT_WARE"
            ;;
        *)
            class_name="OTHER_CLASS"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# エラータイプチェック
# ------------------------------------------------------------------------------
checkErrorType() {
    case "${errpt_type}" in
        INFO)
            getMessage "WD0300I"
            ;;
        PERM)
            getMessage "WD0399C"
            ;;
        *)
            getMessage "WD0399W"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# ログ出力
# ------------------------------------------------------------------------------
throwErrpt() {
    out_flag="0"        # 出力するかどうかを判断するフラグをリセット(0=出力する)
    checkExcludeList    # 除外メッセージに該当するかどうかのフラグを立てる。
    
    # ログ出力
    if [[ "$out_flag" = "0" ]]; then
        checkErrorClass     # エラークラス(HARD, SOFT, Other...)をチェックし、メッセージへ反映させる。
        checkErrorType      # エラータイプ(INFO, TEMP, UNKN, PERM...)をチェックし、メッセージへ反映させる。
        #logWriter ${LOGFILE} "${class_name} ${message} TYPE=${errpt_type} RESOURCE=${errpt_resource} SQNO=${errpt_sqno} ID=${errpt_id} CLASS=${errpt_class}"
        logWriter ${LOGFILE} "${class_name} ${message} TYPE=${errpt_type} RESOURCE=${errpt_resource} SQNO=${errpt_sqno}"
    fi
}

# ==============================================================================
# メイン処理
# ==============================================================================
errpt_sqno=$1
errpt_id=$2
errpt_class=$3
errpt_type=$4
errpt_resource=$5

throwErrpt

exit 0
