;;; verify-egg-string-as.el --- Validate egg-string-as-* wrappers -*- lexical-binding: t; -*-

;; Version: 0.4

;; Author: Chiaki Ishikawa with the help of sometimes buggy ChatGPT
;; (for Tamago-tsunagi verification)
;; Keywords: tamago, emacs, encoding, compatibility, verification

;;; Commentary:
;; This script checks the consistency of `egg-string-as-unibyte` and
;; `egg-string-as-multibyte` with Emacs’s native `string-as-*` APIs.
;;
;; Added in v0.4:
;;  - Collects and reports mismatches into buffer *egg-verify-report*.
;;  - EUC/binary sequences are automatically skipped to avoid false positives.
;;
;; Run:
;;   (load "verify-egg-string-as.el")
;;   (egg-verify-all)
;;   (switch-to-buffer "*egg-verify-report*")
;;
;; To run strict (no skip filter):
;;   (egg-verify-all t)

;;; Code:

(require 'egg-com)
(require 'egg-compatibility)
;;;(require 'verify-egg-string-as)
(require 'egg-integration-verify)
(require 'egg-integration-dual-diff)
(require 'egg-compatibility)
;;; The following is for testing.
;;; (require 'egg-integration-tests)


;;; to include cl-oddpZ
(require 'cl-lib)


(defvar egg-verify-report-buffer "*egg-verify-report*"
  "Name of buffer used to collect verification results.")

(defvar egg--registered-codings
  '(utf-8 euc-jp euc-cn euc-kr euc-tw)
  "テスト対象となるコーディングシステムの一覧。")

;;; ============================================================
;;; Basic EGG configuration defaults (recovered section)
;;; ============================================================

(defvar egg-default-coding 'utf-8
  "Default coding system for EGG operations. Usually 'utf-8.")

(defvar egg-internal-mode t
  "If non-nil, use internal-mode behavior in EGG tests.")

(defvar egg-string-as-debug-flag nil
  "If non-nil, enable debug string output for EGG integration tests.")

(defvar egg--integration-tests nil
  "List of registered integration test definitions for EGG.")


(defun egg--explain-mismatch (orig converted)
  "Return diagnostic info for mismatch between ORIG and CONVERTED.
分類: :length, :prefix, :charset, :unknown"
  (cond
   ;; 長さ違いは最も明確な異常
   ((not (= (length orig) (length converted)))
    (format "LENGTH differs: %d vs %d"
            (length orig) (length converted)))

   ;; 元と先頭一致しているが途中で変化
   ((string-prefix-p converted orig)
    "PREFIX truncated (可能性: 途中で切れたデータ)")

   ((string-prefix-p orig converted)
    "PREFIX extended (可能性: デコード時にゴミ付加)")

   ;; 文字コード・バイト長の違い
   ((and (= (string-bytes orig) (string-bytes converted))
         (not (string= orig converted)))
    (format "BYTE length same (%d) but characters differ — possibly multibyte reinterpretation"
            (string-bytes orig)))

   ;; どの分類にも当てはまらない場合
   (t "Unclassified mismatch (manual inspection required)")))


;;; ============================================================
;;; Skip 判定ロジック
;;; ============================================================

(defun egg-verify-skip-p (str &optional coding)
  "Return non-nil if STR should be skipped from verification.
CODING may hint which codec or context is being verified."
  (or
   ;; ASCII only
   (string-match-p "^[\000-\177]*$" str)
   ;; Binary-like (Tamago RPC)
   (and (memq coding '(egg-binary fixed-euc-py-cn fixed-euc-zy-cn
                       fixed-euc-py-tw fixed-euc-zy-tw))
        (> (length str) 0))
   ;; Contains raw 0x80 and looks like EUC-CN/TW
   (and (string-match-p "\x80" str)
        (memq coding '(euc-cn euc-tw)))
   ;; Odd-length EUC byte string
   (cl-oddp (length str))
   ;; Very short
   (< (length str) 2)))


;;; ============================================================
;;; 内部ヘルパー：出力バッファ
;;; ============================================================
(defun egg--integration-log (fmt &rest args)
  "内部テストおよび比較ログ関数。
FMT と ARGS を使って *EGG-Log* および *egg-verify-report* に追記する。
`egg-string-as-debug-flag` が非nilのときは echo area にも出力する。
バッファが肥大化した場合は自動的に先頭をtruncateする。"
  (let* ((msg-body (apply #'format fmt args))
         (timestamp (format-time-string "[%Y-%m-%d %H:%M:%S] "))
         (msg (concat timestamp msg-body "\n"))
         (max-size (* 200 1024))) ;; 200 KB soft limit
    ;; --- *EGG-Log* に出力 ---
    (with-current-buffer (get-buffer-create "*EGG-Log*")
      (goto-char (point-max))
      ;; サイズチェック（大きすぎる場合はtruncate）
      (when (> (buffer-size) max-size)
        (goto-char (/ (buffer-size) 2))
        (delete-region (point-min) (point))
        (insert "[EGG-LOG truncated due to size limit]\n\n"))
      (insert msg))

    ;; --- *egg-verify-report* にも同期出力（存在する場合のみ）---
    (when (get-buffer "*egg-verify-report*")
      (with-current-buffer "*egg-verify-report*"
        (goto-char (point-max))
        (when (> (buffer-size) max-size)
          (goto-char (/ (buffer-size) 2))
          (delete-region (point-min) (point))
          (insert "[EGG-REPORT truncated due to size limit]\n\n"))
        (insert msg)))

    ;; --- Verbose 出力（エコーエリア）---
    (when (bound-and-true-p egg-string-as-debug-flag)
      (message "[EGG-LOG] %s" msg-body))))


;; Now the defun in egg-integration-tests.el is used
;;
;; (defun egg--test-invalid-bytes-common (coding invalid-bytes)
;;   "テスト用: INVALID-BYTES を CODING として decode し、一貫性を検証する。
;; 常に詳細ログを *EGG-Log* に出力する。"
;;   (let* ((decoded (condition-case err
;;                      (decode-coding-string invalid-bytes coding)
;;                    (coding-system-error
;;                     (format "[ERROR:%s] %s" coding err))))
;;         (re-encoded (when (stringp decoded)
;;                       (encode-coding-string decoded coding)))
;;         (result (equal invalid-bytes re-encoded)))
;;    ;; 常に詳細ログを出力する
;;    (egg--integration-log
;;     (format "[invalid-bytes:%s] %s"
;;             coding
;;             (cond
;;              ((string-match-p "^\\[ERROR" decoded)
;;               (format "Decode error → %s" decoded))
;;              (result "Decoded identically → OK")
;;              (t "Re-encode mismatch → NG"))))
;;    result))



;;; ============================================================
;;; 主検証エントリ
;;; ============================================================



;;
;; 🧠 補足（設計意図）
;;
;; Tamago時代の辞書ファイルや漢字コードは EUC-JP / EUC-KR / EUC-TW に
;; 依存しており、modern Emacs (UTF-8デフォルト) と挙動が異なることがあ
;; ります。
;;
;; dual-mode テストは、両方の挙動を安全に確認して、「どちらでも破綻し
;; ない」実装を保証するためのものです。
;; 
;; 不一致が見つかった場合は、egg--integration-log 経由でその箇所が報告
;; されます。
;;

;;---------------------------------------------
;; EGG Logging subsystem (revived modernized)
;;---------------------------------------------
(defun egg-integration-log (fmt &rest args)
  "Log message to *EGG-Log* buffer (creating it if necessary), and to minibuffer."
  (let ((msg (apply #'format fmt args))
        (buf (get-buffer-create "*EGG-Log*")))
    (with-current-buffer buf
      (goto-char (point-max))
      (insert (format-time-string "[%Y-%m-%d %H:%M:%S] "))
      (insert msg "\n"))
    (message "%s" msg)))

;;
;; 両モードで egg-verify-all-extended を順に実行します。
;;
;; それぞれの結果を *EGG-Log* バッファに書き出します。
;;
;; 最終的に summary は ((t OK) (nil OK)) のような形式で返ります。
;;
;; verbose を指定すると内部の詳細比較も有効になります。
;;






(defun egg-verify--prepare-buffer ()
  "Ensure `egg-verify-report-buffer` exists and is writable."
  (let ((buf (get-buffer-create egg-verify-report-buffer)))
    (with-current-buffer buf
      (erase-buffer)
      (insert (format "Tamago/Tsunagi Encoding Verification Report\nGenerated: %s\n\n"
                      (current-time-string)))
      (insert (format "%-10s | %-12s | %-20s | %-20s\n"
                      "TYPE" "STATUS" "INPUT" "DETAIL"))
      (insert (make-string 72 ?-) "\n"))
    buf))

(defun egg-verify--append-report (type status str detail)
  "Append one verification record to report buffer."
  (with-current-buffer (get-buffer-create egg-verify-report-buffer)
    (insert (format "%-10s | %-12s | %-20s | %-20s\n"
                    type status
                    (truncate-string-to-width (format "%S" str) 20)
                    (truncate-string-to-width detail 20)))))


;;; ============================================================
;;; 単一比較ユニット
;;; ============================================================

(defun egg--verify-one (str convert-fn std-fn label &optional coding)
  "Compare CONVERT-FN result with STD-FN for STR.
LABEL is printed in message output. CODING gives context."
  (if (egg-verify-skip-p str coding)
      (egg-verify--append-report label "SKIP" str (or (symbol-name coding) "auto"))
    (let* ((new (funcall convert-fn str))
           (old (ignore-errors (funcall std-fn str))))
      (if (equal new old)
          (egg-verify--append-report label "OK" str "")
        (let* ((reason
                (cond
                 ;; 長さが異なる場合
                 ((not (= (length new) (length old)))
                  (format "LENGTH differs: new=%d old=%d" (length new) (length old)))
                 ;; new が old の prefix
                 ((and (stringp new) (stringp old)
                       (string-prefix-p new old))
                  "PREFIX truncated (likely partial conversion)")
                 ;; old が new の prefix
                 ((and (stringp new) (stringp old)
                       (string-prefix-p old new))
                  "PREFIX extended (likely extra bytes appended)")
                 ;; バイト長が同じだが文字が違う
                 ((and (stringp new) (stringp old)
                       (= (string-bytes new) (string-bytes old))
                       (not (string= new old)))
                  (format "BYTE length same (%d) but chars differ — likely multibyte reinterpretation"
                          (string-bytes new)))
                 ;; fallback
                 (t "Unclassified mismatch (manual inspection recommended)"))))
          (message "[egg-verify] ⚠ MISMATCH in %s\n  str: %S\n  new: %S\n  old: %S\n  → %s"
                   label str new old reason)
          (egg-verify--append-report label "MISMATCH" str reason)
          (egg--integration-log "[MISMATCH:%s] %S → %S (%s)"
                                label old new reason))))))


;;; ============================================================
;;; 主検証エントリ
;;; ============================================================

;;;
;;; TODO/FIXME () did not match
(defun egg-verify-all (&optional strict)
  "Check `egg-string-as-multibyte' and `egg-string-as-unibyte' consistency.
If STRICT is non-nil, do not skip any test cases (even binary-like data).
Otherwise, skip known false-positive cases like EUC or binary blocks.

This runs a small set of representative sample strings and compares
results between old `string-as-*` and new `egg-string-as-*` functions."
  (interactive "P")
  (let ((samples
         '("" "A" "あ" "漢字"
           "\244\242"               ; EUC-JP lead byte
           "\244\242\200"           ; EUC-JP invalid continuation
           "\216\246"               ; EUC-JP Kana
           "\244\242\244\244"       ; double byte sequence
           "\371\376"               ; binary-like
           "abc򀷯")))              ; mixed (UTF-8 surrogate area)
    (dolist (s samples)
      (unless (and (not strict)
                   (egg-verify-skip-p s))
        ;; Compare with both old and new functions
        (egg--verify-one s
                         #'egg-string-as-multibyte
                         #'string-as-multibyte
                         "multibyte")
        (egg--verify-one s
                         #'egg-string-as-unibyte
                         #'string-as-unibyte
                         "unibyte"))))
  (message "[egg-verify-all] verification completed."))

(defun egg-verify-all-extended (&optional strict)
  "多言語対応の string-as-* 検証を行う。
STRICT が non-nil の場合は false-positive を許容しない。"
  (require 'cl-lib)
  (let* ((samples
          ;; 各言語別のサンプル（生バイト列も混在）
          '("" "A" "あ" "漢字"
            ;; 日本語 EUC-JP
            "\245\242\245\246"        ; 「カキ」
            ;; 中国語 EUC-CN
            "\270\345"                ; 「你」
            "\317\356"                ; 「好」
            ;; 中国語 EUC-TW
            "\241\274"                ; 「。」「，」など
            ;; 韓国語 EUC-KR
            "\270\255"                ; 「가」
            "\270\301"                ; 「나」
            ;; ギリシャ語 ISO-8859-7
            "\306"                    ; 「Α」
            "\336"                    ; 「Ω」
            ;; タイ語 TIS-620
            "\270"                    ; 「ก」
            "\320"                    ; 「ม」
            ;; バイナリ系（false positive 検証）
            "\000\377\200\001"
            "\377\376\000\000"))
         (total 0)
         (mismatch 0))
    (dolist (s samples)
      (cl-incf total)
      (unless (and (not strict) (egg-verify-skip-p s))
        (condition-case err
            (progn
              (egg--verify-one s #'egg-string-as-multibyte #'string-as-multibyte "multibyte")
              (egg--verify-one s #'egg-string-as-unibyte #'string-as-unibyte "unibyte"))
          (error
           (cl-incf mismatch)
           (message "[Mismatch %d/%d] %S → %s"
                    mismatch total s (error-message-string err))))))
    (message "egg-verify-all-extended finished: %d samples, %d mismatches"
             total mismatch)
    (list :total total :mismatch mismatch))) 

;;
;; 🧠 補足（設計意図）
;;
;; Tamago時代の辞書ファイルや漢字コードは EUC-JP / EUC-KR / EUC-TW に
;; 依存しており、modern Emacs (UTF-8デフォルト) と挙動が異なることがあ
;; ります。
;;
;; dual-mode テストは、両方の挙動を安全に確認して、「どちらでも破綻し
;; ない」実装を保証するためのものです。
;; 
;; 不一致が見つかった場合は、egg--integration-log 経由でその箇所が報告
;; されます。
;;

;;
;; 両モードで egg-verify-all-extended を順に実行します。
;;
;; それぞれの結果を *EGG-Log* バッファに書き出します。
;;
;; 最終的に summary は ((t OK) (nil OK)) のような形式で返ります。
;;
;; verbose を指定すると内部の詳細比較も有効になります。
;;




;; 🔧 差分ユーティリティ
(defun egg--string-diff (a b)
  "Return a simple unified diff string between A and B."
  (let* ((tmpA (make-temp-file "eggA"))
         (tmpB (make-temp-file "eggB"))
         (diffbuf (get-buffer-create " *egg-diff*")))
    (unwind-protect
        (progn
          (with-temp-file tmpA (insert a))
          (with-temp-file tmpB (insert b))
          (with-current-buffer diffbuf
            (erase-buffer)
            (if (zerop (call-process "diff" nil diffbuf nil "-u" tmpA tmpB))
                (insert "(no diff)\n")))
          (with-current-buffer diffbuf
            (buffer-string)))
      (delete-file tmpA)
      (delete-file tmpB)
      (when (buffer-live-p diffbuf)
        (kill-buffer diffbuf)))))

(defun egg--integration-log-header ()
  "Insert a standard header at the top of *egg-verify-report*."
  (with-current-buffer (get-buffer-create "*egg-verify-report*")
    (erase-buffer)
    (insert (format "==== EGG Verify Report ====\nStarted: %s\n\n"
                    (format-time-string "%Y-%m-%d %H:%M:%S")))
    (goto-char (point-max))))

(defun egg--integration-log-footer ()
  "Append a footer with end time to *egg-verify-report*."
  (when (get-buffer "*egg-verify-report*")
    (with-current-buffer "*egg-verify-report*"
      (insert (format "\nFinished: %s\n==== END OF REPORT ====\n"
                      (format-time-string "%Y-%m-%d %H:%M:%S")))
      (goto-char (point-max)))))

;;;
;;; egg-verify-all-extended-dual-mode-with-diff may belong to egg-integration-tests.el
;;; HOWEVER since it calls egg--integration-log, we place this here.
;;;
;;; Beware of subtle lexical-scope issue.
;;;
(defun egg--integration-log-section (section-title)
  "セクションタイトルを見やすくログに出す。"
  (egg--integration-log "-------------------------------------------")
  (egg--integration-log "==== %s ====" section-title)
  (egg--integration-log "-------------------------------------------"))

;; now the one defined in egg-integration-tests.el is used.
;; (defun egg--verify-wrapper (fn)
;;  "Run test function FN with timing and logging."
;;  (let* ((start (float-time))
;;         (result (condition-case err
;;                     (funcall fn)
;;                   (error
;;                    (egg--integration-log "[egg-verify] %s → ERROR (%s)"
;;                                          fn err)
;;                    nil)))
;;         (elapsed (- (float-time) start)))
;;    (egg--integration-log "[egg-verify] %s        → %s   (%.3f sec)"
;;                          fn
;;                          (if result "OK" "NG")
;;                          elapsed)
;;    result))



;;
;; The following has been copied to egg-integration-tests.el.
;;
;; (defun egg-verify-all-extended-dual-mode-with-diff ()
;;   "EGG の全統合テストを内部/外部モード両方で実行する。
;; INTERNAL モード (egg-internal-mode=t) と UTF-8 モード (egg-internal-mode=nil)
;; の両方で全テストを走らせ、ログにそれぞれの結果を記録する。"
;;   (let* ((total-start (float-time))
;;          (start-wall (format-time-string "%Y-%m-%d %H:%M:%S"))
;;          (sections '(("INTERNAL" . t) ("UTF-8" . nil)))
;;          (section-results nil))
;; 
;;     ;; 設定スナップショットを出力
;;     (egg--integration-log "==== [EGG TEST CONFIGURATION SNAPSHOT] ====")
;;     (egg--integration-log "egg-internal-mode              : %s" egg-internal-mode)
;;     (egg--integration-log "egg-string-as-debug-flag       : %s" egg-string-as-debug-flag)
;;     (egg--integration-log "egg-default-coding             : %s" (bound-and-true-p egg-default-coding))
;;     (egg--integration-log "buffer-file-coding-system      : %s" buffer-file-coding-system)
;;     (egg--integration-log "===========================================")
;; 
;;     ;; 各モード (internal / utf-8) でテストを実行
;;     (dolist (pair sections)
;;       (let* ((section (car pair))
;;              (mode (cdr pair))
;;              (egg-internal-mode mode)
;;              (section-start (float-time))
;;              (results nil))
;; 
;;         (egg--integration-log-section
;;          (format "Running tests with egg-internal-mode=%s (%s)"
;;                  (if egg-internal-mode "ON" "OFF")
;;                  (if egg-internal-mode "emacs-internal" "utf-8")))
;; 
;;         ;; (A) Pre-write encoding tests
;;         (setq results
;;               (append results
;;                       (mapcar #'(lambda (fn)
;;                                   (egg--verify-wrapper fn))
;;                               '(egg-test-pre-write-encode-utf8-jp
;;                                 egg-test-pre-write-encode-sjis
;;                                 egg-test-pre-write-encode-euc-jp
;;                                 egg-test-pre-write-encode-fixed-euc-china
;;                                 egg-test-pre-write-encode-euc-cn
;;                                 egg-test-pre-write-encode-euc-tw
;;                                 egg-test-pre-write-encode-euc-kr))))
;; 
;;         ;; (B) Invalid byte sequence tests
;;         (egg--integration-log "==== (B) Invalid byte sequence tests (%s) ====" section)
;;         (mapc #'(lambda (fn)
;;                   (egg--verify-wrapper fn))
;;               '(egg-test-invalid-bytes-euc-jp
;;                 egg-test-invalid-bytes-euc-kr
;;                 egg-test-invalid-bytes-euc-cn
;;                 egg-test-invalid-bytes-euc-tw
;;                 egg-test-invalid-bytes-utf-8))
;; 
;;         ;; 経過時間を出力
;;         (let ((elapsed (- (float-time) section-start)))
;;           (egg--integration-log "[SECTION %s] Total elapsed time: %.3f sec" section elapsed)
;;           (push (list :mode mode :total (length results) :elapsed elapsed)
;;                 section-results))))
;; 
;;     ;; サマリ
;;     (egg--integration-log "==== Dual-mode summary ====")
;;     (dolist (entry (reverse section-results))
;;       (egg--integration-log "internal-mode=%s  => (:total %d :elapsed %.6f)"
;;                             (if (plist-get entry :mode) "t" "nil")
;;                             (plist-get entry :total)
;;                             (plist-get entry :elapsed)))
;; 
;;     (egg--integration-log "==== TOTAL elapsed time: %.3f sec ===="
;;                           (- (float-time) total-start))
;;     (egg--integration-log "==== END Dual-mode Test ====")))



;;; ============================================================
;;; Emacs 側 fallback 定義（旧バージョン用）
;;; ============================================================

;;(cl-eval-when-compile
;;  (message"\nexpect obsoleted function referencesL string-as-unibutyes and string-as-multibytes\n"))

;; FIXME  what the defuns are for?
;; (unless (fboundp 'string-as-unibyte)
;;   (defun string-as-unibyte (str) str))
;; (unless (fboundp 'string-as-multibyte)
;;   (defun string-as-multibyte (str) str))


(provide 'verify-egg-string-as)
;;; verify-egg-string-as.el ends here
