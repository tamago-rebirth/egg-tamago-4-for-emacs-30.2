What have been changed.

すべての元からあるファイルには -*- lexical-scope: nil -*- を入れた。

- string-as-*  を新しい関数を使うラッパー関数でお0気か得た

- FUTURE TODO: Use of obarray as hash -> use pure hash functions
- 'intangible property のより問題のない用法を追求すべき。

docomp.el

 すべてのファイルのコンパイル時に 最初に呼ばれるので、
 debug 途中のダンプ目的として以下を入れた。
 (setq byte-compile-debug t)
 (setq debug-on-error t)

----------------------------------------
egg-cnv.el
 egg-buffer-has-markers-at  を buffer-has-markers-at の代りに利用。

egg.el
        fboundp -> boundp の変更
        'egg-mode -> #'egg-mode に変更

-    (set (if (fboundp 'deactivate-current-input-method-function)
+    (set (if (boundp 'deactivate-current-input-method-function)

-	 'egg-mode)
+	 #'egg-mode)

its.el:
 debug 文を入れた
 its compaction の際に  
 its-compaction-null-node をシンボルで明示した。

+(defun debug-print (label value)
+  (message "%s: %S" label value)
+  value)
+
+(defconst its-compaction-null-node :its-null-node
+  "Tamago ITS map compaction における終端ノードのマーカー。")
+


Eager macroexpansion のエラーを避けるための変更
 (defmacro define-its-state-machine (map name indicator lang doc &rest exprs)

its-compaction-integer-table は 0 でなくて nil の初期化が必須！

-	    (its-compaction-integer-table (make-vector 137 0))
+	    ;; 0 ではなく nil にしておく（cdr が数値にならないように）
+	    (its-compaction-integer-table (make-vector 137 nil))



    make-vector DDD nil と
    make-vector DDD 0   の違い。

        Debugger entered--Lisp error: (wrong-type-argument listp 0)
          cdr(0) <--- 誤って vector の初期値を nil でなくて ０ にしていたせい
                      だと気づくのに時間がかかった。macroexpansion の問題だと
                      ばかり思っていた。
          (setcar parent (cdr hash))
          (if (eq lr 'car) (setcar parent (cdr hash)) (setcdr parent (cdr hash)))

its/hangul.el
macroexpansion のエラーの修正
               eval-when をとってしまう。
               macroexpansion が大きくなり過ぎてコンパイルできないので defmacro -> defun
               (defun its-define-hangul (list)

               それにともない 引数を quote 

its/hira.el
        eval-when をとってしまう。

its/kana.el

----------------------------------------
cf.
https://maikaze.cafe.coocan.jp/wnn8.html
https://yanmoo.blogspot.com/2011/07/64bitemacswnn7eggbackend-timeout.html
https://blog.mindboardapps.com/posts/wnn8-on-freebsd-and-emacs-wnn7egg/


考察：
古いegg として利用できていた /usr/local/share/emacs/site-lisp/egg アーカイ
ブ は .elc を全部消した状態で 30.2 で動作する。egg で入力ができる。

じゃあ、これの. elc も含めてどこまで再現、再度作成できるかというと次の
手順。

しかし、全部 の .elc の再現はできない。 macroexpansion に基づくエラー
があるので .elc は全部はできない。だけど、.el があれば使える。

手順：

古い使えていた/usr/local/share/emacs/site-lisp/egg のアーカイブ を
/tmp/egg に展開する。

# コンパイルされたコード  .elc は消す。

rm *.elc egg/*.elc its/*.elc

/tmp/egg に  tamago-... のアーカイブから docomp.el jisx0213.el をコピー
する。

cd /tmp/egg
それぞれのディレクトリで byte-compile する。
以下はそれぞれのディレクトリで別々に行なった。

/tmp/egg では
for f in *.el; do ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file -no-init-file -l ./docomp.el -l ./jisx0213.el -f batch-byte-compile $f; done

/tmp/egg/{egg,its} では
for f in *.el; do ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file
-no-init-file -l ../docomp.el -l ../jisx0213.el -f batch-byte-compile $f; done

多分次のコマンドで全部のファイルコンパイルができる。
for f in *.el egg/*.el its/*.el
do
  ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file -no-init-file -l ./docomp.el -l ./jisx0213.el -f batch-byte-compile $f; done
done

too eager macroexpansion でcompile に失敗する物もある。

だけど、その場合には .elc が作成されないだけなので、その状態の
/tmp/egg
で
/usr/local/share/emacs/site-lisp/egg
を置き換えると とりあえず カナ漢字変換入力を egg でできる事が判明！

========================================

コンパイルの事例：
ishikawa@ip030:/tmp/egg$ for f in *.el; do ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file -no-init-file -l ./docomp.el -l ./jisx0213.el -f batch-byte-compile $f; done
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

   ./docomp.el がないと次のようなエラーがでる。

Error: file-missing ("Cannot open load file" "No such file or directory" "./docomp.el")
  load("./docomp.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "egg-cnv.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./docomp.el
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

./jisx0213 がない時のエラー。

Error: file-missing ("Cannot open load file" "No such file or directory" "./jisx0213.el")
  load("./jisx0213.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "docomp.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./jisx0213.el
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

  docomp.el  jisx0213.el をコピーしたあと。

ishikawa@ip030:/tmp/egg$ for f in *.el; do ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file -no-init-file -l ./docomp.el -l ./jisx0213.el -f batch-byte-compile $f; done
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
docomp.el:34:30: Warning: ‘max-specpdl-size’ is an obsolete variable (as of 29.1).
docomp.el:34:7: Warning: ‘max-specpdl-size’ is an obsolete variable (as of 29.1).
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
egg-cnv.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
egg-com.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line

In fixed-euc-jp-post-read-conversion:
egg-com.el:80:16: Warning: ‘string-as-unibyte’ is an obsolete function (as of 26.1); use ‘encode-coding-string’.

In pre-write-encode-fixed-euc-china:
egg-com.el:552:14: Warning: ‘string-as-multibyte’ is an obsolete function (as of 26.1); use ‘decode-coding-string’.

In decode-fixed-euc-china-region:
egg-com.el:565:19: Warning: ‘string-as-unibyte’ is an obsolete function (as of 26.1); use ‘encode-coding-string’.
egg-com.el:582:20: Warning: ‘string-as-multibyte’ is an obsolete function (as of 26.1); use ‘decode-coding-string’.
egg-com.el:597:18: Warning: ‘string-as-multibyte’ is an obsolete function (as of 26.1); use ‘decode-coding-string’.
egg-com.el:617:24: Warning: ‘string-as-unibyte’ is an obsolete function (as of 26.1); use ‘encode-coding-string’.
egg-com.el:617:46: Warning: ‘string-as-unibyte’ is an obsolete function (as of 26.1); use ‘encode-coding-string’.

In comm-unpack-binary-data:
egg-com.el:898:6: Warning: ‘string-as-unibyte’ is an obsolete function (as of 26.1); use ‘encode-coding-string’.
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
egg-edep.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
egg-mlh.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
egg-sim.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line

In make-non-iso2022-code-table-file:
egg-sim.el:436:18: Warning: ‘format’ called with 1 argument to fill 0 format fields
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
egg-util.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
egg.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
egg.el:36:2: Warning: Package cl is deprecated
egg.el:44:11: Warning: in defgroup for ‘egg’: fails to specify containing group

In egg-redraw-face:
egg.el:270:10: Warning: ‘inhibit-point-motion-hooks’ is an obsolete variable (as of 25.1); use ‘cursor-intangible-mode’ or ‘cursor-sensor-mode’ instead
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
its-keydef.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
its-keydef.el:37:2: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
its.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
its.el:34:2: Warning: Package cl is deprecated

In its-set-part-1:
its.el:891:10: Warning: ‘inhibit-point-motion-hooks’ is an obsolete variable (as of 25.1); use ‘cursor-intangible-mode’ or ‘cursor-sensor-mode’ instead

In its-set-part-2:
its.el:899:10: Warning: ‘inhibit-point-motion-hooks’ is an obsolete variable (as of 25.1); use ‘cursor-intangible-mode’ or ‘cursor-sensor-mode’ instead
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
leim-list.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
menudiag.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
ishikawa@ip030:/tmp/egg$ cd egg
ishikawa@ip030:/tmp/egg/egg$ ls
./   canna.el	cannarpc.el   sj3.el   sj3rpc.el   wnn.el   wnnrpc.el
../  canna.elc	cannarpc.elc  sj3.elc  sj3rpc.elc  wnn.elc  wnnrpc.elc
ishikawa@ip030:/tmp/egg/egg$ for f in *.el
> do
> ^C
ishikawa@ip030:/tmp/egg/egg$ for f in *.el; do ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file -no-init-file -l ./docomp.el -l ./jisx0213.el -f batch-byte-compile $f; done
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

Error: file-missing ("Cannot open load file" "No such file or directory" "./docomp.el")
  load("./docomp.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "canna.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./docomp.el
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

Error: file-missing ("Cannot open load file" "No such file or directory" "./docomp.el")
  load("./docomp.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "cannarpc.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./docomp.el
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

Error: file-missing ("Cannot open load file" "No such file or directory" "./docomp.el")
  load("./docomp.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "sj3.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./docomp.el
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

Error: file-missing ("Cannot open load file" "No such file or directory" "./docomp.el")
  load("./docomp.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "sj3rpc.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./docomp.el
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

Error: file-missing ("Cannot open load file" "No such file or directory" "./docomp.el")
  load("./docomp.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "wnn.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./docomp.el
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

Error: file-missing ("Cannot open load file" "No such file or directory" "./docomp.el")
  load("./docomp.el" nil t)
  command-line-1(("-l" "./docomp.el" "-l" "./jisx0213.el" "-f" "batch-byte-compile" "wnnrpc.el"))
  command-line()
  normal-top-level()
Cannot open load file: No such file or directory, ./docomp.el
ishikawa@ip030:/tmp/egg/egg$ for f in *.el; do ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file -no-init-file -l ../docomp.el -l ../jisx0213.el -f batch-byte-compile $f; done
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
canna.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
canna.el:33:11: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
cannarpc.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
sj3.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
sj3.el:34:11: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
sj3rpc.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
wnn.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
wnn.el:35:11: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
wnnrpc.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
wnnrpc.el:39:6: Warning: ‘string-as-unibyte’ is an obsolete function (as of 26.1); use ‘encode-coding-string’.
ishikawa@ip030:/tmp/egg/egg$ cd ./its
bash: cd: ./its: No such file or directory
ishikawa@ip030:/tmp/egg/egg$ cd ./its
bash: cd: ./its: No such file or directory
ishikawa@ip030:/tmp/egg/egg$ ls
./   canna.el	cannarpc.el   sj3.el   sj3rpc.el   wnn.el   wnnrpc.el
../  canna.elc	cannarpc.elc  sj3.elc  sj3rpc.elc  wnn.elc  wnnrpc.elc
ishikawa@ip030:/tmp/egg/egg$ cd ..
ishikawa@ip030:/tmp/egg$ ls
./	    egg/	 egg-com.elc   egg-mlh.elc  egg-util.elc  its/		  its.elc	leim-list.el
../	    egg-cnv.el	 egg-edep.el   egg-sim.el   egg.el	  its-keydef.el   its.el~	leim-list.elc
docomp.el   egg-cnv.elc  egg-edep.elc  egg-sim.elc  egg.elc	  its-keydef.elc  jisx0213.el	menudiag.el
docomp.elc  egg-com.el	 egg-mlh.el    egg-util.el  eggrc	  its.el	  jisx0213.elc	menudiag.elc
ishikawa@ip030:/tmp/egg$ cd its
ishikawa@ip030:/tmp/egg/its$ ls
./   ascii.el  bixing.el  hangul.el   hira.el	  kata.el    quanjiao.el  zenkaku.el
../  aynu.el   erpin.el   hankata.el  jeonkak.el  pinyin.el  thai.el	  zhuyin.el
ishikawa@ip030:/tmp/egg/its$ !for
for f in *.el; do ~/repos/emacs-30.2/src/emacs -batch -q -no-site-file -no-init-file -l ../docomp.el -l ../jisx0213.el -f batch-byte-compile $f; done
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
ascii.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
ascii.el:33:2: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
aynu.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
aynu.el:33:2: Warning: Package cl is deprecated
aynu.el:127:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
bixing.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
bixing.el:34:2: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
erpin.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
erpin.el:34:2: Warning: Package cl is deprecated
erpin.el:193:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
hangul.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
hangul.el:35:2: Warning: Package cl is deprecated
hangul.el:107:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
hankata.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
hankata.el:31:2: Warning: Package cl is deprecated
hankata.el:46:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
hira.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
hira.el:34:2: Warning: Package cl is deprecated
hira.el:75:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
jeonkak.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
jeonkak.el:35:2: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
kata.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
kata.el:36:2: Warning: Package cl is deprecated
kata.el:56:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
pinyin.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
pinyin.el:33:2: Warning: Package cl is deprecated
pinyin.el:202:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
quanjiao.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
quanjiao.el:33:2: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
thai.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
thai.el:34:2: Warning: Package cl is deprecated
thai.el:85:2: Error: Wrong type argument: listp, 0
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
zenkaku.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
zenkaku.el:33:2: Warning: Package cl is deprecated
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

In toplevel form:
zhuyin.el:1:1: Warning: file has no ‘lexical-binding’ directive on its first line
zhuyin.el:34:2: Warning: Package cl is deprecated
zhuyin.el:38:2: Warning: ‘eval-when’ is an obsolete alias (as of 27.1); use ‘cl-eval-when’ instead.
zhuyin.el:149:2: Error: Wrong type argument: listp, 0
ishikawa@ip030:/tmp/egg/its$ ls -l
total 320
drwxr-xr-x 2 ishikawa ishikawa  4096 10月  4 06:48 ./
drwxr-xr-x 4 ishikawa ishikawa  4096 10月  4 06:46 ../
-rw-r--r-- 1 ishikawa ishikawa  1586  8月  7  2023 ascii.el
-rw-rw-r-- 1 ishikawa ishikawa  3256 10月  4 06:47 ascii.elc
-rw-r--r-- 1 ishikawa ishikawa 13648  8月  7  2023 aynu.el  ← *
-rw-r--r-- 1 ishikawa ishikawa 11278  8月  7  2023 bixing.el
-rw-rw-r-- 1 ishikawa ishikawa 13289 10月  4 06:47 bixing.elc
-rw-r--r-- 1 ishikawa ishikawa 20236  8月  7  2023 erpin.el ← ＊
-rw-r--r-- 1 ishikawa ishikawa 88426  8月  7  2023 hangul.el ← ＊
-rw-r--r-- 1 ishikawa ishikawa 11519  8月  7  2023 hankata.el ← ＊
-rw-r--r-- 1 ishikawa ishikawa 23428  8月  7  2023 hira.el ← ＊
-rw-r--r-- 1 ishikawa ishikawa  5819  8月  7  2023 jeonkak.el
-rw-rw-r-- 1 ishikawa ishikawa  3722 10月  4 06:47 jeonkak.elc
-rw-r--r-- 1 ishikawa ishikawa 22947  8月  7  2023 kata.el ← ＊
-rw-r--r-- 1 ishikawa ishikawa 20749  8月  7  2023 pinyin.el ← ＊
-rw-r--r-- 1 ishikawa ishikawa 10493  8月  7  2023 quanjiao.el
-rw-rw-r-- 1 ishikawa ishikawa  7483 10月  4 06:47 quanjiao.elc
-rw-r--r-- 1 ishikawa ishikawa  5483  8月  7  2023 thai.el ← ＊
-rw-r--r-- 1 ishikawa ishikawa  5630  8月  7  2023 zenkaku.el
-rw-rw-r-- 1 ishikawa ishikawa  3724 10月  4 06:48 zenkaku.elc
-rw-r--r-- 1 ishikawa ishikawa 14095  8月  7  2023 zhuyin.el ← ＊
ishikawa@ip030:/tmp/egg/its$ cd ..
ishikawa@ip030:/tmp/egg$ ls
./	    egg/	 egg-com.elc   egg-mlh.elc  egg-util.elc  its/		  its.elc	leim-list.el
../	    egg-cnv.el	 egg-edep.el   egg-sim.el   egg.el	  its-keydef.el   its.el~	leim-list.elc
docomp.el   egg-cnv.elc  egg-edep.elc  egg-sim.elc  egg.elc	  its-keydef.elc  jisx0213.el	menudiag.el
docomp.elc  egg-com.el	 egg-mlh.el    egg-util.el  eggrc	  its.el	  jisx0213.elc	menudiag.elc
ishikawa@ip030:/tmp/egg$ ls -l
total 784
drwxr-xr-x  4 ishikawa ishikawa   4096 10月  4 06:46 ./
drwxrwxrwt 36 root     root     233472 10月  4 06:44 ../
-rw-r--r--  1 ishikawa ishikawa   1428 10月  4 06:32 docomp.el
-rw-rw-r--  1 ishikawa ishikawa    347 10月  4 06:46 docomp.elc
drwxr-xr-x  2 ishikawa ishikawa   4096 10月  4 06:47 egg/
-rw-r--r--  1 ishikawa ishikawa  45647  8月  7  2023 egg-cnv.el
-rw-rw-r--  1 ishikawa ishikawa  40820 10月  4 06:46 egg-cnv.elc
-rw-r--r--  1 ishikawa ishikawa  42765  8月  7  2023 egg-com.el
-rw-rw-r--  1 ishikawa ishikawa  30032 10月  4 06:46 egg-com.elc
-rw-r--r--  1 ishikawa ishikawa   3482  8月  7  2023 egg-edep.el
-rw-rw-r--  1 ishikawa ishikawa   2211 10月  4 06:46 egg-edep.elc
-rw-r--r--  1 ishikawa ishikawa  16495  8月  7  2023 egg-mlh.el
-rw-rw-r--  1 ishikawa ishikawa  11689 10月  4 06:46 egg-mlh.elc
-rw-r--r--  1 ishikawa ishikawa  17843  8月  7  2023 egg-sim.el
-rw-rw-r--  1 ishikawa ishikawa  13939 10月  4 06:46 egg-sim.elc
-rw-r--r--  1 ishikawa ishikawa   1938  8月  7  2023 egg-util.el
-rw-rw-r--  1 ishikawa ishikawa    801 10月  4 06:46 egg-util.elc
-rw-r--r--  1 ishikawa ishikawa  12329  8月  7  2023 egg.el
-rw-rw-r--  1 ishikawa ishikawa   9463 10月  4 06:46 egg.elc
-rw-r--r--  1 ishikawa ishikawa  12080  8月  7  2023 eggrc
drwxr-xr-x  2 ishikawa ishikawa   4096 10月  4 06:48 its/
-rw-r--r--  1 ishikawa ishikawa   5166  8月  7  2023 its-keydef.el
-rw-rw-r--  1 ishikawa ishikawa  19568 10月  4 06:46 its-keydef.elc
-rw-r--r--  1 ishikawa ishikawa  54304  9月 27 06:25 its.el
-rw-rw-r--  1 ishikawa ishikawa  43049 10月  4 06:46 its.elc
-rw-r--r--  1 ishikawa ishikawa  54314  8月  7  2023 its.el~
-rw-r--r--  1 ishikawa ishikawa   1290 10月  4 05:46 jisx0213.el
-rw-rw-r--  1 ishikawa ishikawa    383 10月  4 06:46 jisx0213.elc
-rw-r--r--  1 ishikawa ishikawa   3972  8月  7  2023 leim-list.el
-rw-rw-r--  1 ishikawa ishikawa   2448 10月  4 06:46 leim-list.elc
-rw-r--r--  1 ishikawa ishikawa  22609  8月  7  2023 menudiag.el
-rw-rw-r--  1 ishikawa ishikawa  17482 10月  4 06:46 menudiag.elc
ishikawa@ip030:/tmp/egg$ cd ..

ishikawa@ip030:/tmp$ sudo bash
[sudo] password for ishikawa: 
root@ip030:/tmp# rm -fr /usr/local/share/emacs/site-lisp/egg
root@ip030:/tmp# mv egg /usr/local/share/emacs/site-lisp/
root@ip030:/tmp# exit
exit
ishikawa@ip030:/tmp$ whch emacs
bash: whch: command not found
[1]+  Done                    emacs
ishikawa@ip030:/tmp$ which emacs
/home/ishikawa/bin/emacs
ishikawa@ip030:/tmp$ emacs
Finished loading /usr/local/share/emacs/site-lisp/egg/leim-list.el 
   and load others...

========================================

対応：


https://maikaze.cafe.coocan.jp/wnn8.html#C2

lexical-binding: nil に全部変更してみる。

cl-when-load などを /usr/local/share/emacs/site-lisp/*.el の先頭にあわ
せる。。。

/opt/ に入れる emacs と, tamago/eggを作って
 通常使うシステムとぶつからないようにする。
 

----------------------------------------

Ugh

古い el, elc を /usr/local/share/emacs/site-lisp/egg に展開する。
そうすると emacs 30.1 でも入力できる。
ただし、eggrc は元どおりにしないといけない。

(if USE-TAMAGO
    (load (expand-file-name "~/.eggrc-tamago")))

macroexpansion で問題があるのは
leim-list.el で
        (when site-run-file
        。。
        )
を外したせいなの＊かも＊しれない。
（＜ー あとで判明 macro expansion で単一の関数が大きくなりすぎて
emacs 30.2 でコンパイルできないソースができる。 hangul の場合。
なので its/hangul.el の関数の引数などの呼び方が少し違う。）

違う。 japanese-egg-wnn というのがinput method の mule-cmds.el がみて
る
list ない！
;;;
;;; Before we reach here, we must have japanese-egg-wnn
;;; defined and included in the alist of converstion methods.


;;; Solarisのばあい？
(if (null (string-match "solaris2.1[01]" system-configuration))
;;; FreeWnn
    (progn
      ;;; (set-input-method 'japanese-egg-wnn)
      (set-input-method 'japanese)
      (toggle-input-method )
      )


----------------------------------------
cl-eval-when, etc. does not get found at emacs startup time.
cl-eval-when-compile, etc. -> eval-when-compile

emacs-29.x start

1. COMMENT OUT ~/.eggrc completely
Otherwise we get egg-startup-file エラー

;;;;;(if USE-TAMAGO
;;;;    (load (expand-file-name "~/.eggrc-tamago")))
;;;  (load (expand-file-name "~/.eggrc-saved")))


Wnn: connecting to jserver at localhost...
Blocking call to accept-process-output with quit inhibited!! [4 times]
Wnn: connecting to jserver at localhost...done
Loading /home/ishikawa/.eggrc...done
egg Japanese backend: 環境を作ることはできませんでした


Probably where the environment is specified in my .eggrc-tamago

Well,

this part of code blows up because egg=-backend-type is not defined
properly now.



 ((eq egg-backend-type 'wnn)
  (cond
   ((eq wnn-server-type 'jserver)
    (if wnn-wnn6-server
	(wnn6-jserver-setup)
      (wnn4-jserver-setup)))

3. So let us do (setq egg-backend-type 'wnn)
and eval-region  withn .eggrc-tamago

    No error?
    きょうは

    (wnn-fail-make-env  "環境を作ることはできませんでした")

4. Where do we enable Japanese input after all?
   Let us temporarily disable it.
   
Debugger entered--Lisp error: (wrong-number-of-arguments #<subr compile> 0)
  compile()
  byte-code("\300\301!\210\300\302!\210\303\304 \305\306\307\"\"\210\310\311\312\313\314\301%\207" [require its cl-lib eval-when compile defconst-1 its-compaction-enable t custom-declare-group hira nil "Hiragana Input Method" :group] 6)
  its-select-hiragana()
  egg-mode("japanese-egg-wnn" its-select-hiragana
  (Japanese ((wnn-backend-Japanese wnn-backend-Japanese
            wnn-backend-Japanese-R))
              ((wnn-backend-Japanese-R wnn-backend-Japanese
  wnn-backend-Japanese-R)))
  (Chinese-GB ((wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZR)) ((wnn-backend-Chinese-GB-PZR wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZR)) ((wnn-backend-Chinese-GB-QR wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-QR)) ((wnn-backend-Chinese-GB-WR wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-WR))) (Chinese-CNS ((wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZR)) ((wnn-backend-Chinese-CNS-PZR wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZR))) (Korean ((wnn-backend-Korean wnn-backend-Korean wnn-backend-Korean-R)) ((wnn-backend-Korean-R wnn-backend-Korean wnn-backend-Korean-R))) (QianMa ((wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-QR))) (WuBi ((wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-WR))))
  apply(egg-mode ("japanese-egg-wnn" its-select-hiragana (Japanese ((wnn-backend-Japanese wnn-backend-Japanese wnn-backend-Japanese-R)) ((wnn-backend-Japanese-R wnn-backend-Japanese wnn-backend-Japanese-R))) (Chinese-GB ((wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZR)) ((wnn-backend-Chinese-GB-PZR wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZR)) ((wnn-backend-Chinese-GB-QR wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-QR)) ((wnn-backend-Chinese-GB-WR wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-WR))) (Chinese-CNS ((wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZR)) ((wnn-backend-Chinese-CNS-PZR wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZR))) (Korean ((wnn-backend-Korean wnn-backend-Korean wnn-backend-Korean-R)) ((wnn-backend-Korean-R wnn-backend-Korean wnn-backend-Korean-R))) (QianMa ((wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-QR))) (WuBi ((wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-WR)))))

  egg-activate-wnn("japanese-egg-wnn" its-select-hiragana)
  activate-input-method(japanese-egg-wnn)
  set-input-method(japanese-egg-wnn)
  (progn (set-input-method 'japanese-egg-wnn) (toggle-input-method))
  (if (null (string-match "solaris2.1[01]" system-configuration)) (progn (set-input-method 'japanese-egg-wnn) (toggle-input-method)) (progn (if nil (setq load-path (append '("~/bin//wnn7/elisp/xemacs21") load-path)) (setq load-path (append '("~/bin/wnn7/elisp/emacs20") load-path))) (global-set-key "\34" 'toggle-input-method) (load "wnn7egg-leim") (if nil (select-input-method "japanese-egg-wnn7") (set-input-method "japanese-egg-wnn7")) (set-language-info "Japanese" 'input-method "japanese-egg-wnn7")))

;;; ========================================
;;; Temporarily disable
;;;(if (string-match "solaris2.1[01]" system-configuration)
;;;    (set-language-environment "Japanese")
;;;  )
;;; ========================================


5. But now we get another error  egg/wnnrpc.el

Loading /home/ishikawa/bin/egg-insert-hack.el (source)...done
Loading /home/ishikawa/bin/tamago-its-defrules.el (source)...done
Loading /home/ishikawa/bin/emacs_vm_customize.elc...

"We are using emacs version 22 and larger. emacs_vm_customize.el"

Loading /home/ishikawa/bin/emacs_vm_customize.elc...done
Before server-start
After server-start
After navi2ch setup
before font setup
Loading egg/wnnrpc (native compiled elisp)...done
Entering debugger...
Mark set
<<< Type SPC or RET to bury the buffer list >>>
(New file)
Quit
Mark saved where search started
<<< Type SPC or RET to bury the buffer list >>>
previous-line: Beginning of buffer [11 times]
Mark set

  compile()
  byte-code("\300\301!\210\300\302!\210\303\304 \305\306\307\"\"\210\310\311\312\313\314\301%\207" [require its cl-lib eval-when compile defconst-1 its-compaction-enable t custom-declare-group hira nil "Hiragana Input Method" :group] 6)
  its-select-hiragana()
  egg-mode("japanese-egg-wnn" its-select-hiragana (Japanese ((wnn-backend-Japanese wnn-backend-Japanese wnn-backend-Japanese-R)) ((wnn-backend-Japanese-R wnn-backend-Japanese wnn-backend-Japanese-R))) (Chinese-GB ((wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZR)) ((wnn-backend-Chinese-GB-PZR wnn-backend-Chinese-GB-PZ wnn-backend-Chinese-GB-PZR)) ((wnn-backend-Chinese-GB-QR wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-QR)) ((wnn-backend-Chinese-GB-WR wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-WR))) (Chinese-CNS ((wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZR)) ((wnn-backend-Chinese-CNS-PZR wnn-backend-Chinese-CNS-PZ wnn-backend-Chinese-CNS-PZR))) (Korean ((wnn-backend-Korean wnn-backend-Korean wnn-backend-Korean-R)) ((wnn-backend-Korean-R wnn-backend-Korean wnn-backend-Korean-R))) (QianMa ((wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-Q wnn-backend-Chinese-GB-QR))) (WuBi ((wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-W wnn-backend-Chinese-GB-WR))))

*** Let us merge the tamago-tsunagi completely for wnnrpc.el and wnn.el***



egg-cnv.el
        (egg-buffer-has-markers-at   used in a few places.
        egg-tsunagi no longer uses it.

========================================

diff -ur --exclude-from=ignore-files.txt  . ~/repos/tamago-tsunagi/ > t.diff

Trying to merge changes in tamago-tsunagi published in 2015
with my changes to older egg tamago circa 2013.

This is to keep using egg.el package for Japanese input
while the underlying emacs-lisp evolves as well as
lisp files in tamago-tsunagi changed.

Evolution means
1 - Obsoleted functions or features in emacs-lisp.
   Most difficult to handle.
2 - Missing functions
   (Second easist to to handle. Simply copy&paste old functions.)
3 - Renamiing of functions. (This is the easist to handle.)

Incompatible changes 

2, 3 occured during the transition of my local tamago package circa
2013

Some features were either missing or used incorrctl and were fixed
during 2013 changes.

But emacs kept on evolving.
Emacs 23 and 24 introduced a few serious chnages in the category
above.


Emacs 30 finally made the current legacy egg/wnn unusable.
We could no longer byte-compile it without some changes.

I. So my first attemp was to make the package compile without
emacs complaining.
I also try to merge tamago-tsunagi modifications with my changes to
the original egg and wnn emacs-lisp files.

This entailed:
Adding file variable:  -*- lexical-scope -*-
cl package is now cl-lib package.

CL-like feature:
eval-when-compile  -> cl-when-compile

Adoption of files from tamago-tsunagi
   check-jisx0213.el   --- used during compilation to see distinguish
                       emacs versions older and 23 and onward.

Files only in tamgo-tsunagi


Only in ~/repos/tamago-tsunagi/: ChangeLog.1997-1998
Only in ~/repos/tamago-tsunagi/: ChangeLog.2000-2001
Only in ~/repos/tamago-tsunagi/: ChangeLog.2002-2004
Only in ~/repos/tamago-tsunagi/: INSTALL
Only in ~/repos/tamago-tsunagi/: NEWS
Only in ~/repos/tamago-tsunagi/: README.ja.UTF-8.txt
Only in ~/repos/tamago-tsunagi/: egg.el.gz
Only in ~/repos/tamago-tsunagi/: egg.el.gz  <--- Trying at this time.

Only in ~/repos/tamago-tsunagi/: helper    <--- helper code writte in c
Only in ~/repos/tamago-tsunagi/egg: anthy.el     NEW lisp code
Only in ~/repos/tamago-tsunagi/egg: anthyipc.el  NEW lisp code
Only in ~/repos/tamago-tsunagi/its: hangul.el.gz <--- there must be
     an incorrect number of argument passed to a function.
     I get an error from  stringp  and all I can think of
     is the call in the form of (stringp )
     I get an error from  characterp  and all I can think of
     is the call in the form of (characterp )

Only in ~/repos/tamago-tsunagi/its: jiskana.el


Files only in my older modified package.


========================================
To compile.

I needed to remove (cl-eval-when-compile )
Simply
--(cl-eval-when-compile
--  (require 'cl-lib))
-+
-+(require 'cl-lib)

I removed require-



its.el
Both:
   TODO/FIXME: PATCHED. last-command-char -> last-command-event were
   both in tsunagi and my local patch

  ;;; TODO/FIXME: PATCHED interactive-p -> called-interactively-p 
    ;;; TODO/FIXME: PATCHED interactive-p -> called-interactively-p 

My change:
   I modified gthe vector size for obarray/hash table to be prime numbers

   string-to-sequence -> string-to-list in my local patch. in two places.

tsunagi change.
   list* -> cl-list*
 
What about the following change in later versions of emacs?

;; The `point-left' hook function will never be called in Emacs 21.2.50
;; when the command `next-line' is used in the last line of a buffer
;; which isn't terminated with a newline or the command `previous-line'
;; is used in the first line of a buffer.
(defun its-next-line (&optional arg)
(defun its-next-line (&optional arg)
  "Go to the end of the line if the line isn't terminated with a newline, otherwise run `next-line' as usual."
  (interactive "p")
  (if (= (line-end-position) (point-max))
      (end-of-line)
    (next-line arg)))

(defun its-previous-line (&optional arg)
  "Go to the beginning of the line if it is called in the first line of a buffer, otherwise run `previous-line' as usual."
  (interactive "p")
  (if (= (line-beginning-position) (point-min))
      (beginning-of-line)
    (previous-line arg)))

(substitute-key-definition 'next-line 'its-next-line
                          its-mode-map global-map)
(substitute-key-definition 'previous-line 'its-previous-line
                          its-mode-map global-map)

   

canna.el
        BOTH
-	      ;;; TODO/FIXME: PATCHED process-kill-without-query
-	      ;;; => (set-process-query-on-exit-flag ... nil)

        tamago-tsunagi      
-		 (eq (process-status (car proc-list)) 'open )
		 (memq (process-status (car proc-list)) '(open run)))


wnnrpc.el

+	  ((eq c 'JS_YOSOKU_INIT)                 ?\xf01001)
+	  ((eq c 'JS_YOSOKU_FREE)                 ?\xf01002)
+	  ((eq c 'JS_YOSOKU_YOSOKU)               ?\xf01003)
+	  ((eq c 'JS_YOSOKU_TOROKU)               ?\xf01004)
+	  ((eq c 'JS_YOSOKU_SELECTED_CAND)        ?\xf01005)
+	  ((eq c 'JS_YOSOKU_DELETE_CAND)          ?\xf01006)
+	  ((eq c 'JS_YOSOKU_CANCEL_LATEST_TOROKU) ?\xf01007)
+	  ((eq c 'JS_YOSOKU_RESET_PRE_YOSOKU)     ?\xf01008)
+	  ((eq c 'JS_YOSOKU_IKKATSU_TOROKU)       ?\xf01009)
+	  ((eq c 'JS_YOSOKU_SAVE_DATALIST)        ?\xf0100a)
+	  ((eq c 'JS_YOSOKU_INIT_TIME_KEYDATA)    ?\xf0100b)
+	  ((eq c 'JS_YOSOKU_INIT_INPUTINFO)       ?\xf0100c)
+	  ((eq c 'JS_YOSOKU_SET_USER_INPUTINFO)   ?\xf0100d)
+	  ((eq c 'JS_YOSOKU_SET_TIMEINFO)         ?\xf0100e)
+	  ((eq c 'JS_YOSOKU_STATUS)               ?\xf0100f)
+	  ((eq c 'JS_YOSOKU_SET_PARAM)            ?\xf01010)
+	  ((eq c 'JS_YOSOKU_IKKATSU_TOROKU_INIT)  ?\xf01011)
+	  ((eq c 'JS_YOSOKU_IKKATSU_TOROKU_END)   ?\xf01012)
+	  ((eq c 'JS_HENKAN_ASSOC)                ?\xf01013)
+

its/thai.el
        I have no idea why/what the changes are.

@@ -70,7 +67,7 @@
 	(setq next-keyseq (concat keyseq (car (car vowel)))
 	      next-output (concat output (cdr (car vowel)))
 	      vowel (cdr vowel))
-        (its-defrule next-keyseq `(eval compose-string ,next-output))
+        (its-defrule next-keyseq (compose-string next-output))
 	(its-thai-add-tone next-keyseq next-output tone))))
 
   (defun its-thai-add-tone (keyseq output tone)
@@ -79,7 +76,7 @@
 	(setq next-keyseq (concat keyseq (car (car tone)))
 	      next-output (concat output (cdr (car tone)))
               tone (cdr tone))
-        (its-defrule next-keyseq `(eval compose-string ,next-output))))))
+        (its-defrule next-keyseq (compose-string next-output))))))

========================================
Only in .: patch-make-coding-system
     
