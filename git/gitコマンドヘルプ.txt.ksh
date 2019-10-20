

https://qiita.com/papi_tokei/items/c9615d618277b5167b79





■事前準備内容で紹介しているコマンド一覧

git config -l
git config --global user.name ユーザ名              ユーザ名設定
git config --global user.email メールアドレス       アドレス設定
git config --global push.default current            プッシュ挙動設定
git config --global --add merge.ff false            マージ挙動設定
git config --global --add pull.ff only              プル挙動設定
git config --global merge.tool vimdiff              マージツール設定
git config credential.helper 'cache --timeout=3600' ログイン時間設定


■
git clone                                   レポジトリ取得
git init                                    レポジトリ初期化
git remote add origin https://ユーザ名@レポジトリ.git       レポジトリURLセット
git remote set-url origin https://ユーザ名@レポジトリ.git   レポジトリURLセット後の変更
git status --short --branch                                 カレントブランチと修正内容表示
git log --oneline --graph                                   グラフでログ表示
git fetch --parge                                           リモートの更新内容有無確認
git pull                                                    リモートの更新内容取得
git add .                                                   ローカル更新内容一括追加
git rm $(git ls-files --deleted)                            削除済ファイルのレポジトリからの一括削除
git commit -m "コメント内容"                                コミット＋一行コメント
git commit -ac HEAD                                         コミット+変更済ファイル追加+ひとつ前のコミットメッセージ活用
git tag -a "タグの名前" -m "タグの中身を示すコメントなど"   タグ追加
git push origin "タグの名前"                                タグをリモートにPush
git checkout                                                取り消したいファイル名 ファイル変更取消
git clean -f                                                トラッキング対象にしていないファイルの削除
git reset --hard HEAD                                       トラッキング対象にしているファイルの変更取消
git commit --amend -m "新しいコメント"                      コミットメッセージの変更
git commit --amend --no-edit                                コミット漏れファイル追加後に実施で、コミットにファイル追加
git reset --soft HEAD^                                      直前コミット取り消し
git push origin :消したいブランチ名                         ブランチ削除




■ステージング系
git add .                   すべて追加
git add file_name           個別ファイルを追加
git commit -m "message"
git statsu                  状況確認
git log                     コミット履歴
git reset HEAD .            すべてアンステージ
git reset HEAD file_name    個別ファイルをアンステージ
git reset --soft HEAD^      コミットのみを取り消す
git reset --hard HEAD^      コミットとその内容すべてを取り消す(注意：変更内容が消えます！！)
git checkout .              すべての変更を取り消す
git checkout file_name      個別ファイルの変更を取り消す
git checkout commit_number  




■リポジトリ
git init                        リポジトリ初期化
git push origin branch_name
git pull origin branch_name             リモートリポジトリの変更を取得し、マージする
git pull --rebase origin master         リモートリポジトリの変更を取得し、マージする（リベースバージョン）
git add remote origin git@XXXXX.git     リモートリポジトリを追加
git fetch origin branch_name            リモートリポジトリの変更を取得
git merge origin/branch_name            リモートリポジトリの変更をマージ
git clone git@XXXXXX.git                リモートリポジトリをローカルにコピー


git init
git add README.md
git commit -m "first commit"
git remote add origin https://github.com/kengoiida/pubrepo.git
git push -u origin master


git ls-files --stage


■ブランチ
git branch -a                  一覧表示
git branch -r               リモート表示
git branch -m hoge fuga     ローカルのブランチ名を変更する
git checkout branch_name    ブランチを切り替える
git branch -d branch_name   ブランチを削除する




git add README.md
git commit -m "first commit"
git remote add origin https://github.com/kengoiida/pubrepo.git
git push -u origin master

…or push an existing repository from the command line
git remote add origin https://github.com/kengoiida/pubrepo.git
git push -u origin master





git show commit_number:file_name            任意のファイルの過去の状態を表示
git diff                                    ワークツリーとインデックスの差分
git diff --cached                           HEADとインデックスの差分
git diff HEAD                               HEADとワークツリーの差分



■
$ git --help
usage: git [--version] [--help] [-C <path>] [-c <name>=<value>]
           [--exec-path[=<path>]] [--html-path] [--man-path] [--info-path]
           [-p | --paginate | -P | --no-pager] [--no-replace-objects] [--bare]
           [--git-dir=<path>] [--work-tree=<path>] [--namespace=<name>]
           <command> [<args>]

These are common Git commands used in various situations:

start a working area (see also: git help tutorial)
   clone     Clone a repository into a new directory
   init      Create an empty Git repository or reinitialize an existing one

work on the current change (see also: git help everyday)
   add       Add file contents to the index
   mv        Move or rename a file, a directory, or a symlink
   restore   Restore working tree files
   rm        Remove files from the working tree and from the index

examine the history and state (see also: git help revisions)
   bisect    Use binary search to find the commit that introduced a bug
   diff      Show changes between commits, commit and working tree, etc
   grep      Print lines matching a pattern
   log       Show commit logs
   show      Show various types of objects
   status    Show the working tree status

grow, mark and tweak your common history
   branch    List, create, or delete branches
   commit    Record changes to the repository
   merge     Join two or more development histories together
   rebase    Reapply commits on top of another base tip
   reset     Reset current HEAD to the specified state
   switch    Switch branches
   tag       Create, list, delete or verify a tag object signed with GPG

collaborate (see also: git help workflows)
   fetch     Download objects and refs from another repository
   pull      Fetch from and integrate with another repository or a local branch
   push      Update remote refs along with associated objects

'git help -a' and 'git help -g' list available subcommands and some
concept guides. See 'git help <command>' or 'git help <concept>'
to read about a specific subcommand or concept.
See 'git help git' for an overview of the system.


