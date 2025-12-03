CHECKED: done

大きな方針：
Compile したコードはインストールしない

defmacro の問題はなくなった。
compile をやめる。
昔から途中の修正がうまく反映できず、ー＞ 結局 emacs 終了して再起動。

なので compile したコードをインストールしない！
(← だけど変更がすぐに反映されないのは require と provide にはいってる
名前と ファイル名のミスマッチとか, when-compile などの一貫してない使用
などが原因だろうなあ。結構な問題)


しかしやはりコードは一度 compile してチェックをしてから .el ファイルのみをinstall し
ている。
その理由は以下の通り。
- 文法エラー のチェック
- obsoleted functions/variables の検出ができるから。

- 各ファイルのcompileへの対応

n/a check-jisx0213.el    コンパイル時に使われる。
n/a docomp.el

    egg-cnv.el

    egg-com.el: このファイルは JIS-code で書かれている事に注意。

		defmacro と実際にテーブルの作成時に呼んでる。ということは
		compile してないのは多数の関数呼出しをスタートアップ
		の初期時に行なうのではないかと思われる

		    egg-com.el:107:(eval-and-compile
		    egg-com.el:131:(eval-and-compile
		    egg-com.el:164:(eval-and-compile
		    egg-com.el:744:(eval-and-compile


n/a egg-compatibility.el       文字列の互換関数。新しい。
n/a egg-edep.el                比較的新しい？ 32, 64 ビット整数のチェック？

n/a egg-integration-dual-diff.el  文字列関数テスト これは lexical-scope: t に注意
                                  テストに使うだけ。

n/a egg-integration-tests.el      テスト
n/a egg-integration-verify.el	  文字列関数テスト これは lexical-scope: t に注意

    egg-mlh.el                    使った事がないと思う。modeless henkan?

    egg-sim.el                    このファイルは JIS-code で書かれている事に注意。
n/a egg-simv.el		  文字コードテーブル？ このファイルは JIS-code で書かれている事に注意。

n/a egg-string-as-mode-test.el	文字列関数テスト これは lexical-scope: t に注意

    egg-util.el
    egg-x0213.el

    egg.el			Version String は更新した方がいいだろ
		うなあ。
		(defgroup egg '((egg-default-language 'custom-variable)
				)
		  "Tamago Version 4.xyz")
		;(defgroup egg nil
		;  "Tamago Version 5.")

n/a execute-test.el   もはや存在しない。 放棄した cursor tracking code lexical-scope: t に注意

??? its-keydef.el   uses the following to define macros.
                    これを残しているが日本語以外の言語で誤動作している
                    かも。
		    its-keydef.el:46:(eval-when-compile
		    its-keydef.el:51:(eval-and-compile

    its.el

    jisx0213.el		

    leim-list.el	site-fileとして呼ばれると いろいろdefineする

    menudiag.el

n/a verify-egg-string-as.el 文字列関数テスト これは lexical-scope: t に注意
        (defun egg-toggle-internal-mode (&optional arg)
        (defun egg--check-consistency (old new coding-system context)
        (defun egg-decode-euc-jp (str &optional context)
        (defun egg-decode-euc-cn (str &optional context)
        (defun egg-decode-utf8 (str &optional context)
        (defun egg-decode-binary (str &optional context)
        (defun egg-encode-euc-jp (str &optional context)
        (defun egg-encode-euc-cn (str &optional context)
        (defun egg-encode-utf8 (str &optional context)
        (defun egg-encode-binary (str &optional context)
        ;;(defun egg-string-as-multibyte (str &optional coding-system)
        ;;(defun egg-string-as-unibyte (str &optional coding-system)
        (defun egg-verify-string-conversion (old new func-name &optional extra-info)
        ;; Use the defun later in this file.
        ;;(defun egg-string-as-multibyte-with-check (str func-name &optional extra-info)
        ;;(defun egg-string-as-unibyte-with-check (str func-name &optional extra-info)
        (defun egg--verify-string-conversion (old new func-name &optional extra-info)
        (defun egg-string-as-multibyte-with-check (str func-name &optional extra-info)
        (defun egg-string-as-unibyte-with-check (str func-name &optional extra-info)
        (defun decode-fixed-euc-china (beg end type)
        (defun egg--choose-coding (coding)
        ;; (defun egg--verify-string-conversion (old new func &optional coding note)
        (defun egg-string-as-multibyte (string &optional _dummy)
        (defun egg-string-as-unibyte (str &optional coding)
        (defun egg--debug-log (fmt &rest args)
        ;; too simple, use older and richer defun in the earlier part of this file.
        ;;(defun egg-verify-string-conversion (old new fn context)
        ;;(defun egg-string-as-multibyte (str)
        ;;(defun egg-string-as-unibyte (str)


＝＝＝＝
現状： 問題になりそうなところは直した。
ただし、日本語以外の利用に問題がないかはその言語のユーザに試してもらい
デバッグしてもらうしかない。

 M-x igrep [return] compile  [return] *.el

docomp.el:1:;;; docomp.el --- compile Egg files -*- lexical-binding: nil -*-
docomp.el:38:(setq byte-compile-warnings '(obsolete redefine callargs); free-vars unresolved
docomp.el:44:(setq byte-compile-debug t)
egg-com.el:107:(eval-and-compile
egg-com.el:131:(eval-and-compile
egg-com.el:164:(eval-and-compile
egg-com.el:744:(eval-and-compile
its-keydef.el:46:(eval-when-compile
its-keydef.el:51:(eval-and-compile
verify-egg-string-as.el:540:;;(cl-eval-when-compile

M-x igrep [return] eval- [return] 
    egg.el:448 uses cl-eval-when で、add-hook で hook が定義される対象の関数定義を取り込む。
    
docomp.el:35:      max-lisp-eval-depth (* 10 max-lisp-eval-depth))
egg-com.el:107:(eval-and-compile
egg-com.el:131:(eval-and-compile
egg-com.el:164:(eval-and-compile
egg-com.el:744:(eval-and-compile
egg.el:448:(cl-eval-when (eval load)
its-keydef.el:46:(eval-when-compile
its-keydef.el:51:(eval-and-compile
verify-egg-string-as.el:540:;;(cl-eval-when-compile

