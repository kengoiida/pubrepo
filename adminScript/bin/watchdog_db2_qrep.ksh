#!/bin/ksh
################################################################################
# 機能概要      : 運用監視 for Q-Replication
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
MW_NAME="QREP"
MW_NAME_MQM="MQM"
DB2_PROFILE=~/sqllib/db2profile
PASSWORD=
MQMUSR="mqm"        # MQ Manager User Default
MQMGRS=             # MQ Manager
MQLSNS=             # MQ Listner
MQCNLS=             # MQ Channel
REP_SVR=            # キャプチャーサーバー or アプライサーバー
rproc=
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
        1)  REP_SVR="$1"
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
    getMessage "000002I";logWriter ${LOGFILE} "${message} ${SCR_NAME}"
}

# ------------------------------------------------------------------------------
# Q Caputure Server Status確認
# ------------------------------------------------------------------------------
watchCAPStatus() {
    MW_NAME="QCAP"
    rproc=${G_QCAP_PROC:=asnqcap}
    
    # 第１引数指定が無い場合はホスト名からレプリケーションプロセス一覧を取得する。
    if [[ "${REP_SVR}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVR="$_OBJ1"    # キャプチャーサーバー一覧
        if [[ "${REP_SVR}" = "" ]]; then
            getMessage "999009I";logWriter ${LOGFILE} "Q-Rep Caputure Server が存在しないのでスキップします。"; return
        fi
    fi

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        getMessage "OPE001I";logWriter ${LOGFILE} "Q-Rep Caputure Server ${svr} の確認${message}"

        # Rep Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"        # インスタンスユーザー
        _schema="$_OBJ2"      # スキーマ名
        MQMGRS="$_OBJ3"      # MQ Manager名
        
        # MQ ステータス確認
        watchMQStatus ${MQMGRS}
        
        # Qrepプロセス確認
        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "Q-Rep Caputure Server ${svr} ${message}"
        else
            getMessage "SWC019I";logWriter ${LOGFILE} "Q-Rep Caputure Server ${svr} ${message}"
        fi

        # Qrep アプリケーション接続確認
        su - ${_user} -c "db2 connect to ${svr}" > /dev/null 2>&1 || return
        procs=$(su - ${_user} -c "db2 list applications" | grep -v grep | grep ${rproc} | wc -l | sed 's/ //g')
        #getMessage "999009I";logWriter ${LOGFILE} "接続アプリケーション数=$procs"

        cat ${WATCH_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'${rproc}'" ) {print $4,$5}}'|while read limit_w limit_c
        do
            # 閾値指定が無い場合は1とみなす
            if [[ "$limit_w" = "" ]]; then limit_w=1; fi
            if [[ "$limit_c" = "" ]]; then limit_c=1; fi
            
            if [[ ${procs} -lt $limit_c ]]; then
                getMessage "WD0042C";logWriter ${LOGFILE} "Q-Repプロセス ${rproc} の接続数が閾値 $limit_c を下回りました。COUNT=${procs}"
            elif [[ ${procs} -lt ${limit_w} ]]; then
                getMessage "WD0042W";logWriter ${LOGFILE} "Q-Repプロセス ${rproc} の接続数が閾値 $limit_w を下回りました。COUNT=${procs}"
            else
                getMessage "WD0042I";logWriter ${LOGFILE} "Q-Repプロセス ${rproc} の接続数は正常値です。 COUNT=${procs}"
            fi
        done
        
        # サブスクリプションステータス確認
        #getMessage "999009I";logWriter ${LOGFILE} "非活動サブスクリプション確認を開始します。"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QCAP_TBL_SUBS:="IBMQREP_SUBS"}.tmp"
        #su - ${_user} -c "db2 -x \"select count(*) from ${_schema}.${G_QCAP_TBL_SUBS} where state != 'A'\""| sed 's/ //g' > ${TMP_LIST}
        #unact=$(cat ${TMP_LIST})
        #if [[ ${unact} -ne 0 ]]; then
        #    getMessage "999009W";logWriter ${LOGFILE} "非活動状態のサブスクリプションが ${unact}件あります。"
        #    RC=3
        #fi

        # 例外表件数確認
        #getMessage "999009I";logWriter ${LOGFILE} "例外表件数確認を開始します。"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QAPP_TBL_EXCEPT:="IBMQREP_EXCEPTIONS"}.tmp"
        #su - ${_user} -c "db2 select SUBNAME, REASON, IS_APPLIED from ${_schema}.${G_QAPP_TBL_EXCEPT}" > ${TMP_LIST}
        #awk ' BEGIN { NUM=0 } $1~"^SUB-" { NUM = NUM + 1 } END { print NUM }' ${TMP_LIST} | read except_val
        #[[ ${except_val} -ne 0 ]] && {
        #    getMessage "999009W";logWriter ${LOGFILE} "例外表に ${except_val} 件の処理が記録されています。"
        #}

        # MQ オブジェクト(Local Queue)取得
        #XXXXXgetObject ${HOSTNAME} ${MW_NAME_MQM}_OBJ ${MQMGRS}
        #XXXXXlocal_q="$_OBJ3"

        # 受信キュー稼働確認 ###
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_recvq.tmp"
        #su - ${_user} -c "db2 select STATE from ${_schema}.IBMQREP_RECVQUEUES" | awk 'BEGIN { NO=0 } {if( $1 == "STATE" ) NO=NR+2 ; if( NR == NO ) { print $1 };}' > ${TMP_LIST}
        #recvq=$(cat ${TMP_LIST})
        #if [[ "${recvq}" != "A" ]] ; then
        #    # FNC_COMM_LOGGING "QREP" "CRIT" "受信キュー "${local_q}" がアクティブ状態ではありません。"
        #    getMessage "999009W";logWriter ${LOGFILE} "受信キュー ${local_q} がアクティブ状態ではありません。"
        #fi

    done
}

# ------------------------------------------------------------------------------
# Q Apply Server Status確認
# ------------------------------------------------------------------------------
watchAPPStatus() {
    MW_NAME="QAPP"
    rproc="${G_QAPP_PROC:=asnqapp}"       # プロセス名

    # 第１引数指定が無い場合はホスト名からレプリケーションプロセス一覧を取得する。
    if [[ "${REP_SVR}" = "" ]]; then
        getObject ${HOSTNAME} ${MW_NAME}
        REP_SVR=$_OBJ1     # Q Repプロセス一覧 取得
        if [[ "${REP_SVR}" = "" ]]; then
            getMessage "999009I";logWriter ${LOGFILE} "Q-Rep Apply Server の指定が存在しないのでスキップします。"; return
        fi
    fi    

    for svr in $(echo "${REP_SVRS}" | sed "s/,/ /g")
    do
        getMessage "OPE001I";logWriter ${LOGFILE} "Q-Rep Apply Server ${svr} の確認${message}"
        # Rep Object 取得
        getObject ${HOSTNAME} ${MW_NAME}_OBJ ${svr}
        _user="$_OBJ1"         # インスタンスユーザー
        _schema="$_OBJ2"      # スキーマ名
        MQMGRS="$_OBJ3"      # MQ Manager名
        
        # MQ ステータス確認
        watchMQStatus ${MQMGRS}

        # Qrepプロセス確認
        checkProcess ${MW_NAME} ${svr}
        if [[ ${procs} -eq 0 ]]; then
            getMessage "WD0041C";logWriter ${LOGFILE} "Q-Rep Apply Server ${svr} ${message}"
        else
            getMessage "SWC019I";logWriter ${LOGFILE} "Q-Rep Apply Server ${svr} ${message}"
        fi

        # Qrep アプリケーション接続確認
        su - ${_user} -c "db2 connect to ${svr}" > /dev/null 2>&1 || return
        procs=$(su - ${_user} -c "db2 list applications" | grep -v grep | grep ${rproc} | wc -l | sed "s/ //g")
        #getMessage "999009I";logWriter ${LOGFILE} "接続アプリケーション数=$procs"

        cat ${WATCH_LIST} | egrep "^${HOSTNAME}:|^COMMON:"|awk -F: '{ if($2 == "'$MW_NAME'" && $3 == "'${rproc}'" ) {print $4,$5}}'|while read limit_w limit_c
        do
            # 閾値指定が無い場合は1とみなす
            if [[ "$limit_w" = "" ]]; then limit_w=1; fi
            if [[ "$limit_c" = "" ]]; then limit_c=1; fi
            
            if [[ ${procs} -lt $limit_c ]]; then
                getMessage "WD0042C";logWriter ${LOGFILE} "Q-repプロセス ${rproc} の接続数が閾値 $limit_c を下回りました。COUNT=${procs}"
            elif [[ ${procs} -lt ${limit_w} ]]; then
                getMessage "WD0042W";logWriter ${LOGFILE} "Q-repプロセス ${rproc} の接続数が閾値 $limit_w を下回りました。COUNT=${procs}"
            else
                getMessage "WD0042I";logWriter ${LOGFILE} "Q-repプロセス ${rproc} の接続数は正常値です。 COUNT=${procs}"
            fi
        done
        
        # サブスクリプションステータス確認
        #getMessage "999009I";logWriter ${LOGFILE} "非活動サブスクリプション確認を開始します。"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QAPP_TBL_TARGET:=IBMQREP_TARGETS}.tmp"
        #su - ${_user} -c "db2 -x \"select count(*) from ${_schema}.${G_QAPP_TBL_TARGET} where state != 'A'\""| sed 's/ //g' > ${TMP_LIST}
        #unact=$(cat ${TMP_LIST})
        #if [[ ${unact} -ne 0 ]]; then
        #    getMessage "999009W";logWriter ${LOGFILE} "非活動状態のサブスクリプションが ${unact}件あります。"
        #    RC=3
        #fi

        # 例外表件数確認
        #getMessage "999009I";logWriter ${LOGFILE} "例外表件数確認を開始します。"
        #TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_${G_QAPP_TBL_EXCEPT:=IBMQREP_EXCEPTIONS}.tmp"
        #su - ${_user} -c "db2 select SUBNAME, REASON, IS_APPLIED from ${_schema}.${G_QAPP_TBL_EXCEPT}" > ${TMP_LIST}
        #awk ' BEGIN { NUM=0 } $1~"^SUB-" { NUM = NUM + 1 } END { print NUM }' ${TMP_LIST} | read except_val
        #[[ ${except_val} -ne 0 ]] && {
        #    getMessage "999009W";logWriter ${LOGFILE} "例外表に ${except_val} 件の処理が記録されています。"
        #}

        # MQ オブジェクト(Local Queue)取得
        #XXXXXgetObject ${HOSTNAME} ${MW_NAME_MQM}_OBJ ${MQMGRS}
        #XXXXXlocal_q="$_OBJS3"

        # 受信キュー稼働確認 ###
        TMP_LIST="${G_SCR_TMP_HOME}/${SCR_NAME}_recvq.tmp"
        su - ${_user} -c "db2 select STATE from ${_schema}.${G_QAPP_TBL_RECVQS:=IBMQREP_RECVQUEUES}" | awk 'BEGIN { NO=0 } {if( $1 == "STATE" ) NO=NR+2 ; if( NR == NO ) { print $1 };}' > ${TMP_LIST}
        recvq=$(cat ${TMP_LIST})
        if [[ "${recvq}" != "A" ]] ; then
            getMessage "999009W";logWriter ${LOGFILE} "受信キュー ${local_q} がアクティブ状態ではありません。"
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

watchCAPStatus
watchAPPStatus

finalizer
exit 0
