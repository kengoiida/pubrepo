

https://qiita.com/papi_tokei/items/c9615d618277b5167b79





�����O�������e�ŏЉ�Ă���R�}���h�ꗗ

git config -l
git config --global user.name ���[�U��              ���[�U���ݒ�
git config --global user.email ���[���A�h���X       �A�h���X�ݒ�
git config --global push.default current            �v�b�V�������ݒ�
git config --global --add merge.ff false            �}�[�W�����ݒ�
git config --global --add pull.ff only              �v�������ݒ�
git config --global merge.tool vimdiff              �}�[�W�c�[���ݒ�
git config credential.helper 'cache --timeout=3600' ���O�C�����Ԑݒ�


��
git clone                                   ���|�W�g���擾
git init                                    ���|�W�g��������
git remote add origin https://���[�U��@���|�W�g��.git       ���|�W�g��URL�Z�b�g
git remote set-url origin https://���[�U��@���|�W�g��.git   ���|�W�g��URL�Z�b�g��̕ύX
git status --short --branch                                 �J�����g�u�����`�ƏC�����e�\��
git log --oneline --graph                                   �O���t�Ń��O�\��
git fetch --parge                                           �����[�g�̍X�V���e�L���m�F
git pull                                                    �����[�g�̍X�V���e�擾
git add .                                                   ���[�J���X�V���e�ꊇ�ǉ�
git rm $(git ls-files --deleted)                            �폜�σt�@�C���̃��|�W�g������̈ꊇ�폜
git commit -m "�R�����g���e"                                �R�~�b�g�{��s�R�����g
git commit -ac HEAD                                         �R�~�b�g+�ύX�σt�@�C���ǉ�+�ЂƂO�̃R�~�b�g���b�Z�[�W���p
git tag -a "�^�O�̖��O" -m "�^�O�̒��g�������R�����g�Ȃ�"   �^�O�ǉ�
git push origin "�^�O�̖��O"                                �^�O�������[�g��Push
git checkout                                                �����������t�@�C���� �t�@�C���ύX���
git clean -f                                                �g���b�L���O�Ώۂɂ��Ă��Ȃ��t�@�C���̍폜
git reset --hard HEAD                                       �g���b�L���O�Ώۂɂ��Ă���t�@�C���̕ύX���
git commit --amend -m "�V�����R�����g"                      �R�~�b�g���b�Z�[�W�̕ύX
git commit --amend --no-edit                                �R�~�b�g�R��t�@�C���ǉ���Ɏ��{�ŁA�R�~�b�g�Ƀt�@�C���ǉ�
git reset --soft HEAD^                                      ���O�R�~�b�g������
git push origin :���������u�����`��                         �u�����`�폜




���X�e�[�W���O�n
git add .                   ���ׂĒǉ�
git add file_name           �ʃt�@�C����ǉ�
git commit -m "message"
git statsu                  �󋵊m�F
git log                     �R�~�b�g����
git reset HEAD .            ���ׂăA���X�e�[�W
git reset HEAD file_name    �ʃt�@�C�����A���X�e�[�W
git reset --soft HEAD^      �R�~�b�g�݂̂�������
git reset --hard HEAD^      �R�~�b�g�Ƃ��̓��e���ׂĂ�������(���ӁF�ύX���e�������܂��I�I)
git checkout .              ���ׂĂ̕ύX��������
git checkout file_name      �ʃt�@�C���̕ύX��������
git checkout commit_number  




�����|�W�g��
git init                        ���|�W�g��������
git push origin branch_name
git pull origin branch_name             �����[�g���|�W�g���̕ύX���擾���A�}�[�W����
git pull --rebase origin master         �����[�g���|�W�g���̕ύX���擾���A�}�[�W����i���x�[�X�o�[�W�����j
git add remote origin git@XXXXX.git     �����[�g���|�W�g����ǉ�
git fetch origin branch_name            �����[�g���|�W�g���̕ύX���擾
git merge origin/branch_name            �����[�g���|�W�g���̕ύX���}�[�W
git clone git@XXXXXX.git                �����[�g���|�W�g�������[�J���ɃR�s�[


git init
git add README.md
git commit -m "first commit"
git remote add origin https://github.com/kengoiida/pubrepo.git
git push -u origin master


git ls-files --stage


���u�����`
git branch -a                  �ꗗ�\��
git branch -r               �����[�g�\��
git branch -m hoge fuga     ���[�J���̃u�����`����ύX����
git checkout branch_name    �u�����`��؂�ւ���
git branch -d branch_name   �u�����`���폜����




git add README.md
git commit -m "first commit"
git remote add origin https://github.com/kengoiida/pubrepo.git
git push -u origin master

�cor push an existing repository from the command line
git remote add origin https://github.com/kengoiida/pubrepo.git
git push -u origin master





git show commit_number:file_name            �C�ӂ̃t�@�C���̉ߋ��̏�Ԃ�\��
git diff                                    ���[�N�c���[�ƃC���f�b�N�X�̍���
git diff --cached                           HEAD�ƃC���f�b�N�X�̍���
git diff HEAD                               HEAD�ƃ��[�N�c���[�̍���



��
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


