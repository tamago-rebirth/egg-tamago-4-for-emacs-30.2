;;; egg-string-as-mode-test.el --- Strict/non-strict mode verification -*- lexical-binding: t; -*-

(require 'egg-compatibility) ;; ← 既存定義を読み込むこと

;;;
;;; テストという部分が euc-cn などでは不正名文字列になっているはず。
;;; そのエラーを検出できないといけない。
;;;
(defvar egg--test-strings
  '(("日本語テスト" . utf-8)
    ("拼音假名テスト" . euc-cn)
    ("韓国어テスト" . euc-kr)
    ("注音假名テスト" . euc-tw)
    ("ASCII only" . us-ascii))
  "テスト対象となる (文字列 . coding-system) のリスト。")

(defun egg--log-result (mode label coding status &optional detail)
  (message "[egg-test][%s] mode=%-6s coding=%-7s result=%s %s"
           label
           (if mode "strict" "loose")
           coding
           (if status "OK" "ERROR")
           (or detail "")))

(defun egg-run-string-as-tests ()
  "egg-string-as-multibyte / unibyte の strict・loose 両モードテストを実行する。"
  (dolist (entry egg--test-strings)
    (let* ((str (car entry))
           (coding (cdr entry)))

      ;; ---- strict mode ----
      (setq egg-string-as-strict-mode t)
      (condition-case err
          (progn
            (let* ((multi (egg-string-as-multibyte str coding))
                   (back  (egg-string-as-unibyte multi coding)))
              (egg--log-result t "roundtrip" coding (stringp back))))
        (error
         (egg--log-result t "roundtrip" coding nil
                          (format "(%s)" (error-message-string err)))))

      ;; ---- loose mode ----
      (setq egg-string-as-strict-mode nil)
      (condition-case err
          (progn
            (let* ((multi (egg-string-as-multibyte str coding))
                   (back  (egg-string-as-unibyte multi coding)))
              (egg--log-result nil "roundtrip" coding (stringp back))))
        (error
         (egg--log-result nil "roundtrip" coding nil
                          (format "(%s)" (error-message-string err))))))))

(defun egg-verify-string-as-all ()
  "全ての文字列について strict / loose モード両方で検証する。"
  (interactive)
  (message "[egg-test] ======= Starting strict / loose mode test =======")
  (egg-run-string-as-tests)
  (message "[egg-test] ======= Completed ======="))

(provide 'egg-string-as-mode-test)
;;; egg-string-as-mode-test.el ends here
