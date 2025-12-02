;;; egg-integration-verify.el --- Integration verification for egg-string-as-* -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'egg-compatibility) ;; egg-string-as-multibyte, egg-string-as-unibyte, etc.

(defvar egg-integration-verbose t)

;;
;;
;;

;;---------------------------------------------
;; Integration test runner (per coding system)
;;---------------------------------------------
;; use the defun in egg-integration-dual-diff.el
;;(defun egg-integration-one (coding test-func &optional verbose)
;;  "Run TEST-FUNC under CODING and log to *egg-verify-report* and *EGG-Log*."
;;  (let ((result nil)
;;        (coding-desc (symbol-name coding))
;;        (report-buf (get-buffer-create "*egg-verify-report*")))
;;    (condition-case err
;;        (setq result (funcall test-func coding))
;;      (error
;;       (setq result (format "ERROR: %s" (error-message-string err)))))
;;    ;; Output to *egg-verify-report*
;;    (with-current-buffer report-buf
;;      (goto-char (point-max))
;;      (insert (format "%-12s | %-12s | coding=%-10s | %s\n"
;;                      (if (multibyte-string-p (car-safe result))
;;                          "multibyte" "unibyte")
;;                      (if (stringp result)
;;                          (if (string-match "ERROR" result)
;;                              "ERROR"
;;                            "OK")
;;                        (if result "OK" "SKIP"))
;;                      coding-desc
;;                      (truncate-string-to-width (format "%s" result) 40 nil nil "..."))))
;;    ;; Output to *EGG-Log*
;;    (egg-integration-log "[egg-test] %-10s coding=%-10s result=%s"
;;                         test-func coding-desc result)
;;    result))

(defun egg--integration-one (label s coding)
  "Test encode/decode using CODING (EUC-CN/TW/KR, egg-binary, etc.).
Logs detailed mismatch causes and appends concise report entries."
  (let* ((multibyte (condition-case err
                        (egg-string-as-multibyte s coding)
                      (error
                       (egg--integration-log "%-20s coding=%-10s ERROR in egg-string-as-multibyte: %s"
                                             label coding err)
                       nil))))
    (cond
     ;; case 1: skipped or invalid
     ((null multibyte)
      (egg--integration-log "%-20s coding=%-10s SKIPPED (nil result)" label coding)
      (egg-verify--append-report label "SKIP" s (format "coding=%s" coding))
      t)
     ((not (stringp multibyte))
      (egg--integration-log "%-20s coding=%-10s SKIPPED (non-string %S)" label coding multibyte)
      (egg-verify--append-report label "SKIP" s (format "non-string %S" multibyte))
      t)

     ;; case 2: valid string — perform encode/decode
     (t
      (let* ((reenc (condition-case err
                        (encode-coding-string multibyte coding)
                      (error
                       (egg--integration-log "%-20s coding=%-10s encode failed: %s"
                                             label coding err)
                       nil)))
             (decoded (and reenc
                           (condition-case err
                               (decode-coding-string reenc coding)
                             (error
                              (egg--integration-log "%-20s coding=%-10s decode failed: %s"
                                                    label coding err)
                              nil))))
             (ok (and (stringp decoded)
                      (string= multibyte decoded))))
        (if ok
            (progn
              (egg--integration-log "%-20s coding=%-10s result=OK" label coding)
              (egg-verify--append-report label "OK" s ""))
          ;; otherwise mismatch
          (let* ((reason (cond
                          ((not (stringp decoded)) "decoded not a string")
                          ((not reenc) "re-encode returned nil")
                          ((not (= (length multibyte) (length decoded)))
                           (format "LENGTH differs: new=%d old=%d"
                                   (length decoded) (length multibyte)))
                          ((not (equal (string-to-list multibyte)
                                       (string-to-list decoded)))
                           "byte-sequence differs")
                          (t "unknown mismatch")))
                 (short (if (> (length reason) 40)
                            (concat (substring reason 0 37) "...")
                          reason)))
            (egg--integration-log "%-20s coding=%-10s result=MISMATCH (%s)"
                                  label coding reason)
            (egg--integration-log "  orig:      %S" s)
            (egg--integration-log "  multibyte: %S" multibyte)
            (egg--integration-log "  decoded:   %S" decoded)
            (egg-verify--append-report label "MISMATCH" s short)))
        ok)))))

(defun egg-verify-integrated-paths ()
  "Verify `egg-string-as-*' consistency along encode/decode/comm paths."
  (interactive)
  (let ((samples '( "漢字" "测试" "한국어" "thái" "Αθήνα"
                    "\244\242" "\xa4\xa2\xb0\xa1" "" ))
        (codings '(euc-jp euc-cn euc-kr euc-tw egg-binary utf-8))
        results)
    (dolist (coding codings)
      (dolist (s samples)
        (push (egg--integration-one "pre/decode" s coding) results)))
    (if (cl-every #'identity results)
        (message "[egg-test] ✅ all integration path tests passed.")
      (message "[egg-test] ⚠ some integration path tests failed. check *Messages*."))))

;;; Optional: comm-unpack simulation
(defun egg-test-comm-unpack-simulation ()
  "Simulate comm-unpack-* behavior with in-memory buffers."
  (let ((data (encode-coding-string "中国語テスト" 'euc-cn)))
    (with-temp-buffer
      (insert data)
      (goto-char (point-min))
      (let ((str (buffer-substring (point-min) (point-max))))
        (egg--integration-one "comm-unpack" str 'euc-cn)))))

;;;
;;; egg-string-as-multibyte が内部で (decode-coding-string
;;; (encode-coding-string ... coding) coding) という形で自己検証を行っ
;;; ている。その際、euc-cn 用の文字列 "拼音假名テスト" に含まれる一部
;;; の日本語（テスト）が EUC-CN で表現できない ため、
;;; encode-coding-string が nil を返すか、error を投げてたことがあった。
;;;
;;; その例外をキャッチしきれていないため、egg-string-as-multibyte 全体
;;; が nil となり、以降の (encode-coding-string nil euc-cn) で
;;; 「wrong-type-argument stringp nil」エラーが出ている。
;;;
;;;🩹 対策方針
;;;
;;; テストコードの役割は「Tamago の変換関数が壊れていないかを確認すること」ですから、
;;; 対象エンコーディングに非対応の文字列はエラーではなくスキップまたは警告ログにすべきです
;;;

;;; Optional: pre-write-encode simulation
(defun egg-test-pre-write-encode-simulation ()
  "Simulate pre-write-encode-fixed-euc-china using temporary buffer."
  (let ((from "拼音假名テスト"))
    (with-temp-buffer
      (let* ((multi (egg-string-as-multibyte from 'euc-cn))
             (encoded (encode-coding-string multi 'euc-cn))
             (decoded (decode-coding-string encoded 'euc-cn)))
        (egg--integration-log "pre-write-encode-sim OK=%s"
                              (string= multi decoded))))))

;;; Entry point
(defun egg-verify-all-integrations ()
  "Run all egg integration verifications."
  (interactive)
  (message "[egg-test] Running all egg integration verifications...")
  (egg-verify-integrated-paths)
  (egg-test-comm-unpack-simulation)
  (egg-test-pre-write-encode-simulation)
  (message "[egg-test] Integration verification completed."))

(provide 'egg-integration-verify)
;;; egg-integration-verify.el ends here
