;;; egg-integration-dual-diff.el --- Dual-mode + diff logging for EGG integration tests -*- lexical-binding: t; -*-

;;; Commentary:
;; このモジュールは、egg-integration テストを
;; - internal モード（egg-binary / emacs-internal）と UTF-8 モードで実行
;; - 結果を *EGG-Log* バッファと *egg-verify-report* バッファに記録
;; - 両モードの結果に差分があれば diff を出力
;;
;; 前提：egg-string-as-multibyte / egg-string-as-unibyte 等が
;;         egg-internal-mode 変数を参照して挙動を切り替える設計になっていること。

;;; Code:

;(defun egg-integration-log (fmt &rest args)
;  "Log message to *EGG-Log* buffer (creating it if needed) and echo."
;  (let ((msg (apply #'format fmt args))
;        (buf (get-buffer-create "*EGG-Log*")))
;    (with-current-buffer buf
;      (goto-char (point-max))
;      (insert (format-time-string "[%Y-%m-%d %H:%M:%S] ")
;              msg "\n"))
;    (message "%s" msg)))

; Use defun in verify-egg-string-as.el
; (defun egg--string-diff (a b)
;  "Return unified diff between strings A and B, or nil if no diff."
;  (let* ((fileA (make-temp-file "eggA"))
;         (fileB (make-temp-file "eggB"))
;         (diffbuf (get-buffer-create " *egg-diff*"))
;         (ret nil))
;    (unwind-protect
;        (progn
;          (with-temp-file fileA (insert a))
;          (with-temp-file fileB (insert b))
;          (with-current-buffer diffbuf
;            (erase-buffer)
;            (if (zerop
;                 (call-process "diff" nil diffbuf nil "-u" fileA fileB))
;                (insert "(no diff)\n")))
;          (setq ret (with-current-buffer diffbuf (buffer-string)))
;          ret)
;      (delete-file fileA)
;      (delete-file fileB)
;      (when (buffer-live-p diffbuf)
;        (kill-buffer diffbuf)))))

(defun egg-integration-one (label test-func coding &optional verbose)
  "Run TEST-FUNC under CODING, log to *EGG-Log* and *egg-verify-report*.
LABEL identifies the kind of test (e.g. \"pre-write\", \"comm-unpack\")."
  (let* ((coding-desc (symbol-name coding))
         (report-buf (get-buffer-create "*egg-verify-report*"))
         (res nil))
    (condition-case err
        (setq res (funcall test-func coding))
      (error
       (setq res (format "ERROR: %s" (error-message-string err)))))
    ;; Append to report buffer
    (with-current-buffer report-buf
      (goto-char (point-max))
      (insert (format "%-10s | %-12s | coding=%-10s | %s\n"
                      label
                      (if (stringp res)
                          (if (string-match-p "^ERROR:" res) "ERROR" "OK")
                        (if res "OK" "SKIP"))
                      coding-desc
                      (truncate-string-to-width (format "%s" res) 40 nil nil "..."))))
    ;; Log to EGG-Log
    (egg-integration-log "[egg-test] %-10s coding=%-10s result=%s"
                         label coding-desc res)
    res))

(defun egg-verify-all-extended-dual-mode (&optional verbose)
  "Run all EGG integration tests twice:
once with `egg-internal-mode` = t (legacy internal coding),
and once with it = nil (UTF-8 mode).
Reports results for both modes separately."
  (interactive "P")
  (let ((modes '(t nil))
        (summary '()))
    (dolist (mode modes)
      (setq egg-internal-mode mode)
      (egg--integration-log
       "==== Running tests with egg-internal-mode=%s ===="
       (if mode "ON (emacs-internal)" "OFF (utf-8)"))
      (let ((result (condition-case err
                        (egg-verify-all-extended verbose)
                      (error
                       (format "ERROR: %s" (error-message-string err))))))
        (push (list mode result) summary)))
    (egg--integration-log "==== Dual-mode summary ====")
    (dolist (entry (reverse summary))
      (egg--integration-log
       "Mode=%s  Result=%s"
       (if (car entry) "internal" "utf-8")
       (cadr entry)))
    (message "[EGG] dual-mode verification complete. See *EGG-Log* buffer for details.")
    summary))


(provide 'egg-integration-dual-diff)
;;; egg-integration-dual-diff.el ends here
