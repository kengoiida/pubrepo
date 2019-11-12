#!/bin/ksh
################################################################################
# 機能概要      : ログメンテナンス
# 実行仕様      : 通常呼び出し（引数なし）
# 読込ファイル  : ${G_SCR_ETC_HOME}/${SCR_NAME}_target.lst
# 書込ファイル  : ${G_SCR_LOG_HOME}/${SCR_NAME}.log
# 戻り値        : 0 以外は異常終了
# 更新履歴      : YYYY/MM/DD    新規作成
################################################################################
# 外部ファイル読込・変数定義
SCR_HOME=$(dirname $0)

[[ -f /.profile ]] && . /.profile >/dev/null
. ${SCR_HOME}/_common_profile.conf
. ${SCR_HOME}/${G_SCR_LIB}

# スクリプト共通ローカル変数定義ブロック（基本的に全てのスクリプトで定義すべき変数群）
SCR_NAME=$(basename $0 ${G_SCR_SFX})                        # スクリプト名取得
HOSTNAME=$(hostname)                                        # ホスト名取得
MSGLIST=${G_SCR_ETC_HOME}/${G_SCR_MSG}                      # スクリプトメッセージ定義ファイル名
MSGMODE=${G_MSGMODE}                                        # メッセージ出力モード
LOGDATE=$(date +%Y%m%d)                                     # スクリプトログファイル名にタイムスタンプを含める場合使用する日付。
LOGFILE=${G_SCR_LOG_HOME}/${SCR_NAME}.log                   # スクリプトログファイル名
LOGGER_TAG=${SCR_NAME}                                      # syslog出力記録用タグ文字列
RC=0                                                        # リターンコードリセット

# スクリプト独自ローカル変数定義ブロック（スクリプト毎に異なる定義の変数群）
TARGET_LIST="${G_SCR_ETC_HOME}/log_maintenance.lst"         # メンテナンスリスト
#MSGMODE=nologging                                           # 
SYSLOG_FACILITY=local6
# ------------------------------------------------------------------------------
# ローテーション・サブ関数
# ------------------------------------------------------------------------------
doLogRotate() {
    target_dir="$2"
    target_file="$3"

    FIND_LIST=$(find ${target_dir} -name "${target_file}")

    for file in $(echo ${FIND_LIST})
    do
        rcount=$1

        if [[ ${rcount} -eq 0 ]]; then
            cp -p ${file} ${file}.$(date '+%Y%m%d_%H%M%S')
        else
            while [ ${rcount} != 1 ]
            do
                [[ -f ${file}.$((rcount-1)) ]] && {
                    cp -p ${file}.$((rcount-1)) ${file}.${rcount}
                }
                ((rcount-=1))
            done
            [ -f ${file} ] && cp -p ${file} ${file}.${rcount}
        fi

        cat /dev/null > ${file}
    done
}

# ==============================================================================
# メイン処理
# ==============================================================================
trap doTrapHandler HUP INT TERM

[[ ! -f ${TARGET_LIST} ]] && {
#    MSGMODE=syslog
    getMessage "LOG000C";logWriter ${LOGFILE} "リストファイルが存在しません。[${TARGET_LIST}]"
    exit 1
}

#getMessage "LOG000I";logWriter ${LOGFILE} "ログメンテナンス処理を開始します。"

for MNTLIST in $(cat ${TARGET_LIST}|awk -F: '{ if($1 == "COMMON" || $1 == "'$HOSTNAME'" ){print $0}}')
do
	type=$(echo ${MNTLIST} |  awk -F: '{ print $2 }')	# メンテナンスタイプ
	expire=$(echo ${MNTLIST} |  awk -F: '{ print $3 }')	# 有効期限 or 有効数
	dir=$(echo ${MNTLIST} |  awk -F: '{ print $4 }')	# 対象ディレクトリ
	file=$(echo ${MNTLIST} |  awk -F: '{ print $5 }')	# ファイル名（ワイルドカード可）

    [[ ! -d ${dir} ]] && continue

    case ${type} in
        delete)
            find ${dir} -name "${file}" -mtime +${expire} -exec rm -f {} \;
            ;;
        daily)
            doLogRotate ${expire} ${dir} "${file}"
            ;;
        weekly*)
            [[ "$(date +%w)" = "$(echo ${type} | cut -c 7-)" ]] && {
                doLogRotate ${expire} ${dir} "${file}"
            }
            ;;
        *)
            ;;
    esac

done

# 非監視ロックフラグファイル削除
#deleteLckFile "watchdog_aix"
#deleteLckFile "watchdog_db2"

#getMessage "LOG000I";logWriter ${LOGFILE} "ログメンテナンス処理を終了します。"

exit 0

