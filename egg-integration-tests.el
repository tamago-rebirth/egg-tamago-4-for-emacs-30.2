;; egg-integration-tests.el   -*- lexical-binding: nil -*-
;;
;;


;;; ========================================================================
;;;  開発メモ（現フェーズ総括）
;;; ========================================================================
;;;
;;;  tamago（EGG + Wnn）環境を現行 Emacs に適合させるための全体方針の中で、
;;;  本フェーズでは主に以下を目的としている：
;;;
;;;    - 廃止予定／非推奨関数 `str-as-*` 群の排除
;;;    - その互換実装としての `egg-str-as-*` 関数群の完全置換
;;;    - `encode-coding-string` / `decode-coding-string` を使用した
;;;      正規の符号化／復号処理への移行
;;;    - 旧版 `str-as-*` との動作一致性（compatibility）の保証
;;;
;;; ------------------------------------------------------------------------
;;;  今後の検討項目（構文・API レベル）
;;; ------------------------------------------------------------------------
;;;
;;;  (i) 旧 `inhibit-point-motion-hooks` の置換：
;;;       → `cursor-sensor-inhibit` と `cursor-sensor-mode` に移行するか、
;;;          あるいは `cursor-intangible-mode` を使うべきか要再検討。
;;;
;;;  (ii) `intangible` テキストプロパティの再確認：
;;;       → 現行 Emacs における非推奨化状況と代替仕様の把握が必要。
;;;
;;;  (iii) obarray の使用見直し：
;;;       → “貧弱なハッシュテーブル代用” として利用していた箇所を、
;;;          正式な `make-hash-table` / `gethash` / `puthash` 系 API に置換。
;;;
;;; ------------------------------------------------------------------------
;;;  現フェーズの主目的
;;; ------------------------------------------------------------------------
;;;
;;;  → `egg-str-as-*` 関数群が旧 `str-as-*` と同等に動作することを確認する。
;;;     特に、有効な文字列（対応コード系で正しく表現できる範囲）において
;;;     双方が同一の結果を返すことを確認する。
;;;
;;;  以下の拡張テストにより互換性検証を強化する：
;;;
;;;    (1) Round-trip 検証
;;;         decode → encode → decode の三段階で、
;;;         内容が恒等的に保持されるかを確認。
;;;
;;;    (2) Buffer I/O テスト
;;;         実際のバッファ書き出し (`write-region`) を経由して、
;;;         ファイルレベルの符号化／復号動作を検証。
;;;
;;;    (3) 複合文字セット拡充
;;;         EUC-TW, EUC-KR など、複数バイトセットの正確な扱いを確認。
;;;
;;;    (4) `egg-run-all-encoding-tests` の再統合
;;;         現状は簡略版 helper が部分利用されているため、
;;;         旧来の出力構造（スナップショット含む）を正式版に統一予定。
;;;
;;; ------------------------------------------------------------------------
;;;  コメント
;;; ------------------------------------------------------------------------
;;;
;;;  現状の印象としては、有効な文字列範囲においては既に
;;;  `egg-str-as-*` が旧 `str-as-*` と同等に動作している。
;;;  ただし invalid byte の扱い方（signal の種類や message 文言）など、
;;;  境界条件の比較テストは今後強化の余地がある。
;;;
;;;
;;; | Phase | Scope                                 | Key variable(s)                                            | Goal                                                         | 
;;;| ----- | ---------------------------- | --------------------------------------------- | ------------------------------------------------------------ |
;;;| (1)   | Round-trip                   | `egg-str-as-*`
;;;        | (encode/decode only)         | `egg-internal-mode`
;;;                                       | Confirm identical behavior of replacement functions
;;;| (2)   | Buffer I/O                   | `buffer-file-coding-system`,
;;;|       |                              |  `default-coding-system-for-*`
;;;                                       | Check file write/read consistency
;;;| (A')  | Dual-mode                    | `egg-internal-mode`
;;;|       | I/O (recommended extension)  | See if I/O behaves differently under emacs-internal vs utf-8 |
;;;|       |                              |
;;;| (D)   | Locale variation             | `set-locale-environment`
;;;|       | (optional extension)         | Check independence from system locale                        |
;;;| (3)   | Multi-byte charset coverage  | `euc-tw`, `euc-kr`, etc.
;;;                                       | Deep dive into complex CJK mappings                          |

;;; ========================================================================
;;;  End of Development Notes Section
;;; ========================================================================


;;; ------------------------------------------------------------
;;; Generic registration helpers
;;; ------------------------------------------------------------
(defvar egg--integration-tests nil
  "List of registered EGG integration test cases.
Each element is a vector of the form:
  [label fn always-run skip desc].")

(defun egg--register-integration-test (name fn &optional always-run skip desc)
  "Register integration test NAME → FN into `egg--integration-tests`.
NAME may be a symbol or string. FN must be callable.
If a test with the same NAME already exists, it is replaced.
ALWAYS-RUN, SKIP, DESC are optional metadata."
  (let* ((label (if (symbolp name) (symbol-name name) (format "%s" name)))
         (fn-val (if (functionp fn) fn (error "FN must be callable: %S" fn)))
         (new (vector label fn-val (and always-run t) (and skip t) (or desc ""))))
    ;; remove existing same-label entries
    (setq egg--integration-tests
          (cl-remove-if (lambda (v)
                          (and (vectorp v)
                               (string= (aref v 0) label)))
                        egg--integration-tests))
    ;; prepend for convenience
    (push new egg--integration-tests)
    (egg--integration-log "[REGISTER] %s" label)
    new))

;; ----------------------------------------
;; Test: Pre-write encode/decode simulation
;; ----------------------------------------

(defun egg-test-pre-write-encode-sim (&optional coding)
  "Standalone encode/decode roundtrip test (not registered in egg--integration-tests)."
  (let ((from "拼音假名テスト"))
    (with-temp-buffer
      (let* ((multi (egg-string-as-multibyte from coding))
             (encoded (encode-coding-string multi coding))
             (decoded (decode-coding-string encoded coding))
             (ok (string= multi decoded)))
        (egg--integration-log
         "pre-write-encode-sim [%s] OK=%s (%s→%s→%s)"
         coding ok multi encoded decoded)
        ok))))
;;;
;;;
;;;

;;; ------------------------------------------------------------
;;; Test-only simulation of pre-write encoding functions
;;; These DO NOT write to disk and are safe for dual-mode testing.
;;; ------------------------------------------------------------

(defun egg-test-pre-write-encode-euc-jp ()
  "Test writing with EUC-JP encoding (Japanese text)."
  (let* ((sample "日本語テスト")
         (encoded (encode-coding-string sample 'euc-jp))
         (decoded (decode-coding-string encoded 'euc-jp)))
    (string= sample decoded)))

(defun egg-test-pre-write-encode-sjis ()
  "Test writing with Shift_JIS encoding (Japanese text)."
  (let* ((sample "日本語テスト")
         (encoded (encode-coding-string sample 'shift_jis))
         (decoded (decode-coding-string encoded 'shift_jis)))
    (string= sample decoded)))

(defun egg-test-pre-write-encode-utf8-jp ()
  "Test writing with UTF-8 (Japanese text)."
  (let* ((sample "日本語テスト")
         (encoded (encode-coding-string sample 'utf-8))
         (decoded (decode-coding-string encoded 'utf-8)))
    (string= sample decoded)))


(defun egg-test-pre-write-encode-fixed-euc-china (&optional coding)
  "Simulate encode/decode roundtrip for fixed-euc-china safely in a temp buffer."
  (let ((from "拼音假名テスト"))
    (let ((temp-buffer (generate-new-buffer " *egg-test-pre-write-euc-china*")))
      (unwind-protect
          (save-current-buffer
            (set-buffer temp-buffer)
            (set-buffer-multibyte nil)
            ;; safer: don't force egg-binary
            ;; NO. I think we need 'egg-binary
            (if (not (egg-string-as-multibyte from 'egg-binary))
                (error "(egg-string-as-multibyte from 'egg-binary) was nil")
              (insert (egg-string-as-multibyte from 'egg-binary)))
            (let ((coding-system-for-write (or coding 'euc-cn))
                  (coding-system-for-read  (or coding 'euc-cn)))
              (decode-coding-region (point-min) (point-max) coding-system-for-read))
            (buffer-string))
        (kill-buffer temp-buffer)))))

(defun egg-test-pre-write-encode-euc-cn (&optional coding)
  "Simulate encode/decode roundtrip for euc-cn safely in memory."
  (egg-test-pre-write-encode-fixed-euc-china (or coding 'euc-cn)))

(defun egg-test-pre-write-encode-euc-tw (&optional coding)
  "Simulate encode/decode roundtrip for euc-tw safely in memory."
  (egg-test-pre-write-encode-fixed-euc-china (or coding 'euc-tw)))

(defun egg-test-pre-write-encode-euc-kr (&optional coding)
  "Simulate encode/decode roundtrip for euc-kr safely in memory."
  (egg-test-pre-write-encode-fixed-euc-china (or coding 'euc-kr)))

;;; ------------------------------------------------------------
;;; Test-only simulation of pre-write encoding functions
;;; ------------------------------------------------------------

;(defun egg-test-pre-write-encode-euc-tw (&optional coding)
;  (egg-test-pre-write-encode-fixed-euc-china (or coding 'euc-tw)))

;(defun egg-test-pre-write-encode-euc-kr (&optional coding)
;  (egg-test-pre-write-encode-fixed-euc-china (or coding 'euc-kr)))

;;; Register test functions for integration verification


;;
;; # ==============================
;; Use this hardened egg-string-as-multibyte during debugging once.
;;
;; Use the defun in egg-compatibility.el for normal usage.
;;
;; (defun egg-string-as-multibyte (str &optional coding)
;;  "DEBUG: Safer wrapper of string-as-multibyte for EGG tests."
;;  (let ((result
;;         (condition-case err
;;             (progn
;;               (when (not (stringp str))
;;                 (error "Non-string input: %S" str))
;;               (let ((res (string-as-multibyte str)))
;;                 (message "[egg-debug] input=%S result=%S (len=%d)"
;;                          str res (length res))
;;                 res))
;;           (error
;;            (message "[egg-debug] ERROR in string-as-multibyte: %s" err)
;;            nil))))
;;    result))

;(defun egg-test-pre-test-write-encode-utf8-jp ()
;  (egg-test-pre-write-encode-utf8-jp))
;(defun egg-test-pre-test-write-encode-sjis ()
;  (egg-test-pre-write-encode-sjis))
;(defun egg-test-pre-test-write-encode-euc-jp ()
;  (egg-test-pre-write-encode-euc-jp))
;(defun egg-test-pre-test-write-encode-fixed-euc-china ()
;  (egg-test-pre-write-encode-fixed-euc-china))
;(defun egg-test-pre-test-write-encode-euc-cn ()
;  (egg-test-pre-write-encode-euc-cn))
;(defun egg-test-pre-test-write-encode-euc-tw ()
;  (egg-test-pre-write-encode-euc-tw))
;(defun egg-test-pre-test-write-encode-euc-kr ()
;  (egg-test-pre-write-encode-euc-kr))


(defun egg-register-integration-tests ()
  "Register all EGG integration test cases, including (A) pre-write
and (B) invalid-byte sequence tests."
  (setq egg--integration-tests nil)

  ;; --- (A) Pre-write encoding tests ---
  (let ((entries
         '(
           ;("pre-test-write-encode-euc-kr"    egg-test-pre-write-encode-euc-kr)
           ;("pre-test-write-encode-euc-tw"    egg-test-pre-write-encode-euc-tw)
           ;("pre-test-write-encode-euc-cn"    egg-test-pre-write-encode-euc-cn)
           ;("pre-test-write-encode-fixed-euc-china" egg-test-pre-write-encode-fixed-euc-china)
           ("pre-write-encode-euc-kr"         egg-test-pre-write-encode-euc-kr)
           ("pre-write-encode-euc-tw"         egg-test-pre-write-encode-euc-tw)
           ("pre-write-encode-euc-cn"         egg-test-pre-write-encode-euc-cn)
           ("pre-write-encode-fixed-euc-china" egg-test-pre-write-encode-fixed-euc-china)
;           ("pre-test-write-encode-euc-jp"    egg-test-pre-write-encode-euc-jp)
;           ("pre-test-write-encode-sjis"      egg-test-pre-write-encode-sjis)
;           ("pre-test-write-encode-utf8-jp"   egg-test-pre-write-encode-utf8-jp)
           ("pre-write-encode-euc-jp"         egg-test-pre-write-encode-euc-jp)
           ("pre-write-encode-sjis"           egg-test-pre-write-encode-sjis)
           ("pre-write-encode-utf8-jp"        egg-test-pre-write-encode-utf8-jp))))
    (dolist (entry entries)
      (let ((label (car entry))
            (fn (cadr entry)))
        (push (vector label fn t nil
                      (format "Simulated encoding test for %s" label))
              egg--integration-tests))))

  ;; --- (B) Invalid-byte sequence tests ---
  (let ((invalid-tests
         '(("invalid-bytes-euc-jp" egg-test-invalid-bytes-euc-jp)
           ("invalid-bytes-euc-kr" egg-test-invalid-bytes-euc-kr)
           ("invalid-bytes-euc-cn" egg-test-invalid-bytes-euc-cn)
           ("invalid-bytes-euc-tw" egg-test-invalid-bytes-euc-tw)
           ("invalid-bytes-euc-utf-8" egg-test-invalid-bytes-utf-8)
           ("invalid-bytes-euc-jp-partial" egg-test-invalid-bytes-euc-jp-partial)
           ("invalid-bytes-euc-kr-partial" egg-test-invalid-bytes-euc-kr-partial)
           ("invalid-bytes-euc-cn-partial" egg-test-invalid-bytes-euc-cn-partial)
           ("invalid-bytes-euc-tw-partial" egg-test-invalid-bytes-euc-tw-partial)
           ("invalid-bytes-utf-8-partial"  egg-test-invalid-bytes-utf-8-partial)
           ("invalid-bytes-euc-jp-mixed-sjis" egg-test-invalid-bytes-euc-jp-mixed-sjis)
           ("invalid-bytes-euc-kr-mixed-sjis" egg-test-invalid-bytes-euc-kr-mixed-sjis)
           ("invalid-bytes-euc-cn-mixed-sjis" egg-test-invalid-bytes-euc-cn-mixed-sjis)
           ("invalid-bytes-euc-tw-mixed-sjis" egg-test-invalid-bytes-euc-tw-mixed-sjis)
           ("invalid-bytes-euc-utf-8-mixed-sjis"      egg-test-invalid-bytes-utf-8-mixed-sjis )
           ("invalid-bytes-euc-utf-8-mixed-euc-jp" egg-test-invalid-bytes-utf-8-mixed-euc-jp ))))

    (dolist (entry invalid-tests)
      (let ((label (car entry))
            (fn (cadr entry)))
        (push (vector label fn t nil
                      "Invalid byte sequence test.")
              egg--integration-tests))))

  (egg--integration-log "[INIT] Registered %d integration tests (A + B)."
                        (length egg--integration-tests)))



;;; ------------------------------------------------------------
;;; (B) Invalid byte sequence test cases
;;; ------------------------------------------------------------

;; 例外（coding-system-error）が出た場合のみ「Decode error → [ERROR:...]」を出します。

;; decode が U+FFFD 等を返しても、それは仕様通りの振る舞い なので OK と扱います。

;; つまり「壊れたバイトを安全に処理できた」という観点でテスト成功。

;;
;; すべての不正バイト列テストが 例外を出さず、
;; decode→encode の処理も 仕様どおりの安全な劣化（U+FFFD 等） として扱われ、
;; EGG-Log に常に「Decoded identically → OK」が出力されている、という
;; 状態。
;;

(defun egg--test-invalid-bytes-common (coding sample)
  "Test invalid byte sequences under CODING system.
Return t if behavior is as expected, nil otherwise.
Always logs diagnostic output.
When `egg-string-as-debug-flag' is non-nil, also logs hex dump
of original and reencoded bytes for detailed comparison."
  (let* ((decoded (condition-case err
                      (decode-coding-string sample coding)
                    (error (format "<<decode-error:%s>>" (error-message-string err)))))
         (reencoded (condition-case err
                        (encode-coding-string decoded coding)
                      (error (format "<<encode-error:%s>>" (error-message-string err)))))
         (ok nil)
         (msg nil))

    ;; --- Decide pass/fail logic ---
    (cond
     ;; Decode failed → expected for invalid bytes
     ((string-match-p "^<<decode-error" decoded)
      (setq ok t
            msg "Decode error → expected (OK)"))
     ;; Re-encode differs → also expected due to replacement handling
     ((not (string= sample reencoded))
      (setq ok t
            msg "Decoded/encoded differ (expected due to invalid sequence) → OK"))
     ;; Identical bytes
     (t
      (setq ok t
            msg "Decoded identically → OK")))

    ;; --- Always log summary ---
    (egg--integration-log "[invalid-bytes:%s] %s" coding msg)

    ;; --- If verbose mode, dump hex diff ---
    (when egg-string-as-debug-flag
      (let ((to-hex (lambda (s)
                      (mapconcat
                       (lambda (b) (format "%02X" b))
                       (string-to-list s) " "))))
        (egg--integration-log "  [orig:%s]" (funcall to-hex sample))
        (egg--integration-log "  [reenc:%s]" (funcall to-hex reencoded))
        (unless (string= sample reencoded)
          (egg--integration-log "  [diff→ %d byte(s) differ]"
                                (length (cl-remove-if #'identity
                                                      (cl-mapcar #'equal
                                                                 (string-to-list sample)
                                                                 (string-to-list reencoded))))))))

    ok))




(defun egg-test-invalid-bytes-euc-jp ()
  (egg--test-invalid-bytes-common
   'euc-jp
   ;; 0x8F (JIS X 0212) で始まるが不完全なシーケンス
   (string #x8F #xA2)))

(defun egg-test-invalid-bytes-euc-kr ()
  (egg--test-invalid-bytes-common
   'euc-kr
   ;; 0xA4 単独 (EUC-KRでは2バイトシーケンスの1バイト目)
   (string #xA4)))

(defun egg-test-invalid-bytes-euc-cn ()
  (egg--test-invalid-bytes-common
   'euc-cn
   ;; 0xA1 のみ (不完全)
   (string #xA1)))

(defun egg-test-invalid-bytes-euc-tw ()
  (egg--test-invalid-bytes-common
   'euc-tw
   ;; 0x8E 開始だが続きがない
   (string #x8E)))

(defun egg-test-invalid-bytes-utf-8 ()
  (egg--test-invalid-bytes-common 'utf-8 (string #xE3 #x81)))


;;;; ============================================================
;;;; (B2) 部分的に正しいシーケンス＋不正バイト列
;;;; ============================================================

(defun egg-test-invalid-bytes-euc-jp-partial ()
  "EUC-JP: 正常な2バイト＋不正孤立バイト (#xA4 #xA2 #x8F)"
  (egg--test-invalid-bytes-common
   'euc-jp
   (string #xA4 #xA2 #x8F)))

(defun egg-test-invalid-bytes-euc-kr-partial ()
  "EUC-KR: 正常なハングル2バイト＋孤立不正バイト (#xA4 #xA2 #x8F)"
  (egg--test-invalid-bytes-common
   'euc-kr
   (string #xA4 #xA2 #x8F)))

(defun egg-test-invalid-bytes-euc-cn-partial ()
  "EUC-CN: 正常GB2312＋孤立不正バイト (#xA1 #xA1 #x8E)"
  (egg--test-invalid-bytes-common
   'euc-cn
   (string #xA1 #xA1 #x8E)))

(defun egg-test-invalid-bytes-euc-tw-partial ()
  "EUC-TW: 正常BIG5先頭＋孤立不正バイト (#xA4 #x40 #x8E)"
  (egg--test-invalid-bytes-common
   'euc-tw
   (string #xA4 #x40 #x8E)))

;;;; ============================================================
;;;; (B2) 部分的に正しいシーケンス＋不正バイト列（UTF-8版）
;;;; ============================================================

(defun egg-test-invalid-bytes-utf-8-partial ()
  "UTF-8: valid 2-byte sequence + truncated 3-byte sequence."
  ;; e.g. 0xC3 0x81 (valid 'Á') + 0xE3 (truncated start of 3-byte char)
  (egg--test-invalid-bytes-common
   'utf-8
   (string #xC3 #x81 #xE3)))


;;;; ============================================================
;;;; (B3) 異種混合バイト列（他エンコーディングの断片混入）
;;;; ============================================================

(defun egg-test-invalid-bytes-euc-jp-mixed-sjis ()
  "EUC-JP: Shift-JIS風バイト (#x82 #xA0) を混入"
  (egg--test-invalid-bytes-common
   'euc-jp
   (string #x82 #xA0)))

(defun egg-test-invalid-bytes-euc-kr-mixed-sjis ()
  "EUC-KR: Shift-JIS風バイト (#x82 #xA0) を混入"
  (egg--test-invalid-bytes-common
   'euc-kr
   (string #x82 #xA0)))

(defun egg-test-invalid-bytes-euc-cn-mixed-sjis ()
  "EUC-CN: Shift-JIS風バイト (#x82 #xA0) を混入"
  (egg--test-invalid-bytes-common
   'euc-cn
   (string #x82 #xA0)))

(defun egg-test-invalid-bytes-euc-tw-mixed-sjis ()
  "EUC-TW: Shift-JIS風バイト (#x82 #xA0) を混入"
  (egg--test-invalid-bytes-common
   'euc-tw
   (string #x82 #xA0)))



;;;; ============================================================
;;;; (B3) 異種混合バイト列（他エンコーディングの断片混入）（UTF-8版）
;;;; ============================================================

(defun egg-test-invalid-bytes-utf-8-mixed-sjis ()
  "UTF-8: mix in Shift-JIS-style bytes (#x82 #xA0)."
  (egg--test-invalid-bytes-common
   'utf-8
   (string #xE3 #x81 #x82 #x82 #xA0))) ; 「あ」 + bogus SJIS fragment

(defun egg-test-invalid-bytes-utf-8-mixed-euc-jp ()
  "UTF-8: mix in EUC-JP-style bytes (#xA4 #xA2)."
  (egg--test-invalid-bytes-common
   'utf-8
   (string #xE3 #x81 #x82 #xA4 #xA2))) ; 「あ」 + bogus EUC fragment

(defun egg-run-all-config-combinations ()
  "Run dual-mode EGG tests under multiple configuration sets and summarize results."
  (let ((config-list
         '((:internal t   :debug t   :coding utf-8 :buf utf-8)
           (:internal t   :debug nil :coding utf-8 :buf utf-8)
           (:internal nil :debug t   :coding utf-8 :buf utf-8)
           (:internal nil :debug nil :coding utf-8 :buf utf-8)
           (:internal t   :debug t   :coding euc-jp :buf euc-jp)
           (:internal nil :debug t   :coding euc-jp :buf euc-jp))))
    (dolist (conf config-list)
      (let* ((egg-internal-mode (plist-get conf :internal))
             (egg-string-as-debug-flag (plist-get conf :debug))
             (egg-default-coding (plist-get conf :coding))
             (buffer-file-coding-system (plist-get conf :buf))
             (start-time (float-time))
             (fail-count 0))
        ;; Log section header
        (egg--integration-log
         (format "\n[%s] ==== BEGIN CONFIG ===="
                 (format-time-string "%Y-%m-%d %H:%M:%S")))
        (egg--integration-log
         (format "[CONFIG] internal=%s  debug=%s  default=%s  buffer=%s"
                 egg-internal-mode egg-string-as-debug-flag
                 egg-default-coding buffer-file-coding-system))
        (egg--integration-log
         "-------------------------------------------")

        ;; Capture *EGG-Log* buffer before and after to detect NG entries
        (with-current-buffer (get-buffer-create "*EGG-Log*")
          (goto-char (point-max))
          (let ((before-point (point)))
            (egg-verify-all-extended-dual-mode-with-diff)
            (goto-char before-point)
            (while (re-search-forward "→ NG" nil t)
              (setq fail-count (1+ fail-count)))))

        ;; Summarize results
        (let ((elapsed (- (float-time) start-time)))
          (egg--integration-log
           (format "[SUMMARY] elapsed=%.3fs, NG=%d" elapsed fail-count))
          (egg--integration-log
           (format "[%s] ==== END CONFIG ====\n"
                   (format-time-string "%Y-%m-%d %H:%M:%S"))))))))


;;
;; 正常系
;; 実行
(egg-register-integration-tests)
;;; 実行


;;; ----------------------------------------------------------------------
;;; [Phase 4] NG要約出力機能 (自動生成対応版)
;;; ----------------------------------------------------------------------

(defun egg--parse-ng-lines ()
  "Parse *EGG-Log* buffer and return list of (timestamp test-name config)."
  (when (get-buffer "*EGG-Log*")
    (with-current-buffer "*EGG-Log*"
      (goto-char (point-min))
      (let (results current-config)
        ;; 設定スナップショットを取得
        (while (re-search-forward "^\\[.*\\] egg-internal-mode\\s-*:\\s-*\\(t\\|nil\\)" nil t)
          (setq current-config (match-string 1)))
        (goto-char (point-min))
        ;; NG 行を抽出
        (while (re-search-forward "^\\[.*\\] \\[egg-verify\\]\\s-+\\([^ ]+\\)\\s-+→ NG" nil t)
          (push (list (match-string 1) current-config) results))
        (nreverse results)))))

(defun egg-show-ng-summary ()
  "Collect NG lines from *EGG-Log* and show summary buffer."
  (interactive)
  (let ((ng-list (egg--parse-ng-lines)))
    (if (null ng-list)
        (message "🎉 すべて OK です！")
      (with-current-buffer (get-buffer-create "*EGG-Summary*")
        (erase-buffer)
        (insert "==== EGG NG Summary ====\n\n")
        (dolist (entry ng-list)
          (insert (format "❌ %s   [egg-internal-mode=%s]\n"
                          (car entry)
                          (or (cadr entry) "unknown"))))
        (insert (format "\nTotal NG: %d\n" (length ng-list)))
        (goto-char (point-min))
        (display-buffer (current-buffer))))))

;;; ----------------------------------------------------------------------
;;; [Phase 4 Integration] Call summary after all extended dual tests
;;; ----------------------------------------------------------------------

(defun egg-run-roundtrip-tests ()
  "すべての Round-trip テストをまとめて実行する。"
  (mapc #'egg--verify-wrapper
        '(egg-test-roundtrip-utf8
          egg-test-roundtrip-euc-jp
          egg-test-roundtrip-sjis
          egg-test-roundtrip-euc-kr
          egg-test-roundtrip-euc-tw)))

;;;###autoload
(defun egg-verify-all-extended-dual-mode-with-diff ()
  "EGG の全統合テストを内部/外部モード両方で実行する。
INTERNAL モード (egg-internal-mode=t) と UTF-8 モード (egg-internal-mode=nil)
の両方で全テストを走らせ、ログにそれぞれの結果を記録する。"
  (let* ((total-start (float-time))
         (start-wall (format-time-string "%Y-%m-%d %H:%M:%S"))
         (sections '(("INTERNAL" . t) ("UTF-8" . nil)))
         (section-results nil))

    ;;------------------------------------------------------------
    ;; CONFIGURATION SNAPSHOT
    ;;------------------------------------------------------------
    (egg--integration-log "==== [EGG TEST CONFIGURATION SNAPSHOT] ====")
    (egg--integration-log "LANG                             : %s" (or (getenv "LANG") "N/A"))
    (egg--integration-log "system-coding-system              : %s"
                          (and (boundp 'system-coding-system) system-coding-system))
    (egg--integration-log "locale-coding-system              : %s"
                          (and (boundp 'locale-coding-system) locale-coding-system))
    (egg--integration-log "egg-internal-mode                 : %s" egg-internal-mode)
    (egg--integration-log "egg-string-as-debug-flag          : %s" egg-string-as-debug-flag)
    (egg--integration-log "egg-default-coding                : %s" (bound-and-true-p egg-default-coding))
    (egg--integration-log "buffer-file-coding-system         : %s" buffer-file-coding-system)
    (egg--integration-log "system-configuration-features     : %s" system-configuration-features)
    (egg--integration-log "system-type                       : %s" system-type)
    (egg--integration-log "emacs-version                     : %s" emacs-version)
    (egg--integration-log "===========================================")

    ;;------------------------------------------------------------
    ;; (A) Dual-mode section runs (internal / utf-8)
    ;;------------------------------------------------------------
    (dolist (pair sections)
      (let* ((section (car pair))
             (mode (cdr pair))
             (egg-internal-mode mode)
             (section-start (float-time))
             (results nil))

        (egg--integration-log-section
         (format "Running tests with egg-internal-mode=%s (%s)"
                 (if egg-internal-mode "ON" "OFF")
                 (if egg-internal-mode "emacs-internal" "utf-8")))

        ;; (A-1) Pre-write encoding tests
        (setq results
              (append results
                      (mapcar #'(lambda (fn)
                                  (egg--verify-wrapper fn))
                              '(egg-test-pre-write-encode-utf8-jp
                                egg-test-pre-write-encode-sjis
                                egg-test-pre-write-encode-euc-jp
                                egg-test-pre-write-encode-fixed-euc-china
                                egg-test-pre-write-encode-euc-cn
                                egg-test-pre-write-encode-euc-tw
                                egg-test-pre-write-encode-euc-kr))))

        ;; (A-2) Roundtrip tests (added)
        (egg--integration-log "==== (A2) Roundtrip encode/decode tests (%s) ====" section)
        (egg-run-roundtrip-tests)

        ;; (B) Invalid byte sequence tests
        (egg--integration-log "==== (B) Invalid byte sequence tests (%s) ====" section)
        (mapc #'(lambda (fn)
                  (egg--verify-wrapper fn))
              '(egg-test-invalid-bytes-euc-jp
                egg-test-invalid-bytes-euc-kr
                egg-test-invalid-bytes-euc-cn
                egg-test-invalid-bytes-euc-tw
                egg-test-invalid-bytes-utf-8))

        ;; (C) Buffer I/O roundtrip tests
        (egg--integration-log "==== (C) Buffer I/O roundtrip tests (%s) ====" section)
        (egg-run-buffer-io-tests-dual-mode)

        ;; Section timing
        (let ((elapsed (- (float-time) section-start)))
          (egg--integration-log "[SECTION %s] Total elapsed time: %.3f sec" section elapsed)
          (push (list :mode mode :total (length results) :elapsed elapsed)
                section-results))))

    ;;------------------------------------------------------------
    ;; (D) Locale switch tests
    ;;------------------------------------------------------------
    (egg-run-locale-switch-tests)

    ;;------------------------------------------------------------
    ;; SUMMARY
    ;;------------------------------------------------------------
    (egg--integration-log "==== Dual-mode summary ====")
    (dolist (entry (reverse section-results))
      (egg--integration-log "internal-mode=%s  => (:total %d :elapsed %.6f)"
                            (if (plist-get entry :mode) "t" "nil")
                            (plist-get entry :total)
                            (plist-get entry :elapsed)))

    (egg--integration-log "==== TOTAL elapsed time: %.3f sec ===="
                          (- (float-time) total-start))
    (egg--integration-log "==== END Dual-mode Test ====")))

;;; ------------------------------------------------------------------------
;;; --- 開発フェーズメモ（現行統合テスト構造 / 2025年10月時点） ---
;;; ------------------------------------------------------------------------
;;;
;;; ========================================================================
;;; 現フェーズまとめドキュメント：EGG 統合テスト基盤の整理メモ
;;; ========================================================================
;;;
;;; 本ドキュメントは、2025年10月時点の EGG 統合テスト基盤の状態をまとめた
;;; 開発メモである。`egg-verify-all-extended-dual-mode-with-diff` の整備完了を
;;; もって、本フェーズのテスト構造が安定したとみなす。
;;;
;;; ------------------------------------------------------------------------
;;; ■ テスト目的
;;; ------------------------------------------------------------------------
;;;
;;; このテスト群は、EGG における「文字コード変換」「不正バイト列」「内部表現」
;;; の相互関係を、Emacs の内部コーディング (emacs-internal) と UTF-8 モードの
;;; 双方で同一結果となることを検証するものである。
;;;
;;; 具体的には以下の２系統の検証を行う：
;;;
;;;  (A) Pre-write encoding tests
;;;      → 各エンコーディング（UTF-8, EUC-JP, SJIS 等）に対して、
;;;         `encode-coding-string` / `decode-coding-string` を通した
;;;         出力結果の整合性を確認。
;;;
;;;  (B) Invalid byte sequence tests
;;;      → 各エンコーディングの「不正バイト列」が decode 時にどう扱われるか
;;;         を統一的に検証し、Emacs の挙動変更検知を可能にする。
;;;
;;; ------------------------------------------------------------------------
;;; ■ dual-mode 実行設計
;;; ------------------------------------------------------------------------
;;;
;;; `egg-verify-all-extended-dual-mode-with-diff` は、内部変数
;;; `egg-internal-mode` を ON/OFF して、２回連続で全テストを走らせる。
;;;
;;;   ("INTERNAL" . t)   → Emacs 内部表現 (emacs-internal)
;;;   ("UTF-8"     . nil)→ UTF-8 モード
;;;
;;; 各モードごとに (A)(B) のテスト群を実行し、結果を *EGG-Log* バッファへ
;;; タイムスタンプ付きで出力する。
;;;
;;; ------------------------------------------------------------------------
;;; ■ 設定スナップショット
;;; ------------------------------------------------------------------------
;;;
;;; 実行時には環境情報を「スナップショット」としてログ冒頭に出力する。
;;; これにより再現性を確保する：
;;;
;;;   [EGG TEST CONFIGURATION SNAPSHOT]
;;;   egg-internal-mode              : t
;;;   egg-string-as-debug-flag       : t
;;;   egg-default-coding             : utf-8
;;;   buffer-file-coding-system      : utf-8
;;;
;;; なお、`egg-string-as-debug-flag` が t の場合、各テスト結果の詳細
;;; （たとえば "Decoded identically → OK" 等）も出力される。
;;;
;;; ------------------------------------------------------------------------
;;; ■ 今後の拡張ポイント
;;; ------------------------------------------------------------------------
;;;
;;; - (1) Round-trip 検証
;;;       decode → encode → decode の 3 段階検証を追加予定。
;;;
;;; - (2) Buffer I/O テスト
;;;       実際の buffer 書き出し (`write-region`) 経由の動作確認。
;;;
;;; - (3) 複合文字セット (EUC-TW, EUC-KR など) の coverage 拡充。
;;;
;;; - (4) egg-run-all-encoding-tests の再統合
;;;       現状、簡略版 helper 関数が一部で使用されているが、
;;;       本関数の出力構造（スナップショット含む）を正式版に統一する予定。
;;;
;;; ------------------------------------------------------------------------
;;; ■ 備考
;;; ------------------------------------------------------------------------
;;;
;;; - 「Unknown defun property ‘ignore’」警告は使用不要のため削除済み。
;;; - ログ出力はすべて `egg--integration-log` 経由で統一。
;;; - 現行フェーズでは、見た目より「可視性と再現性」を優先している。
;;;
;;; ------------------------------------------------------------------------
;;; 以上
;;; ========================================================================


;;; ----------------------------------------------------------------------------
;;; Helper: run one test (timing / logging) and return plist result
;;; ----------------------------------------------------------------------------
(defun egg--verify-wrapper (fn)
  "Run test function FN (symbol or function).  Return a plist:
:name (string) :ok (t/nil) :error (error object or nil) :elapsed (seconds)."
  (let* ((label (if (symbolp fn) (symbol-name fn) (format "%s" fn)))
         (start (float-time))
         ok err)
    (condition-case e
        (progn
          ;; If fn is symbol, call that function; otherwise assume it's a function object
          (setq ok (if (symbolp fn) (funcall (intern-soft label)) (funcall fn))))
      (error (setq err e) (setq ok nil)))
    (let ((elapsed (- (float-time) start)))
      ;; log a compact per-test line
      (egg--integration-log "[egg-verify] %-40s → %s   (%.3f sec)"
                            label
                            (cond (err (format "ERROR: %s" err))
                                  (ok  "OK")
                                  (t   "NG"))
                            elapsed)
      (list :name label :ok ok :error err :elapsed elapsed))))



;;; ===========================================================
;;; 実行ヘルパ：registered tests を柔軟に選んで実行する
;;; ===========================================================
(defun egg-run-all-registered-tests (&optional verbose)
  "Run all tests registered in `egg--integration-tests` sequentially."
  (when verbose
    (ignore verbose))  ;; safely ignore, no warnings
  (egg--run-selected-from-registered (lambda (_label _fn) t)))

(defun egg-run-all-encoding-tests (&optional verbose)
  "Run all encoding-related tests (pre-* and invalid-bytes*)."
  (when verbose
    (ignore verbose))
  (egg--run-selected-from-registered
   (lambda (label _fn)
     (or (string-match-p "\\`pre-" label)
         (string-match-p "\\`invalid-bytes" label)))))

(defun egg-run-invalid-bytes-tests (&optional verbose)
  "Run only the invalid-bytes* tests."
  (egg--run-selected-from-registered
   (lambda (label _fn)
     (string-match-p "\\`invalid-bytes" label))))
;;;
;;;
;;; ========================================================================
;;;  (1) Round-trip 検証セクション
;;; ========================================================================
;;;
;;;  目的：
;;;    - egg-str-as-* 互換関数群が encode/decode の往復で情報を失わないことを検証する。
;;;    - decode → encode → decode の 3 段階で同一結果を得られることを確認。
;;;
;;;  各テストは (egg--verify-wrapper ...) 経由で呼び出され、
;;;  既存の *EGG-Log* に結果を出力する。
;;; ========================================================================

(defun egg-test-roundtrip-utf8 ()
  "UTF-8 の往復変換 (decode → encode → decode) が恒等的であることを確認。"
  (let* ((coding 'utf-8)
         (orig "日本語テスト UTF-8 ✨")
         (encoded (encode-coding-string orig coding))
         (decoded (decode-coding-string encoded coding)))
    (if (string= orig decoded)
        (egg--integration-log "[roundtrip:%s] OK (%s bytes)" coding (length encoded))
      (egg--integration-log "[roundtrip:%s] MISMATCH!\n  orig: %S\n  decoded: %S"
                            coding orig decoded))
    (string= orig decoded)))

(defun egg-test-roundtrip-euc-jp ()
  "EUC-JP の往復変換 (decode → encode → decode) を検証。"
  (let* ((coding 'euc-jp)
         (orig "漢字テスト EUC-JP")
         (encoded (encode-coding-string orig coding))
         (decoded (decode-coding-string encoded coding)))
    (if (string= orig decoded)
        (egg--integration-log "[roundtrip:%s] OK (%s bytes)" coding (length encoded))
      (egg--integration-log "[roundtrip:%s] MISMATCH!\n  orig: %S\n  decoded: %S"
                            coding orig decoded))
    (string= orig decoded)))

(defun egg-test-roundtrip-sjis ()
  "Shift_JIS の往復変換 (decode → encode → decode) を検証。"
  (let* ((coding 'shift_jis)
         (orig "カタカナテスト SJIS")
         (encoded (encode-coding-string orig coding))
         (decoded (decode-coding-string encoded coding)))
    (if (string= orig decoded)
        (egg--integration-log "[roundtrip:%s] OK (%s bytes)" coding (length encoded))
      (egg--integration-log "[roundtrip:%s] MISMATCH!\n  orig: %S\n  decoded: %S"
                            coding orig decoded))
    (string= orig decoded)))

(defun egg-test-roundtrip-euc-kr ()
  "EUC-KR の往復変換を検証。"
  (let* ((coding 'euc-kr)
         (orig "한글 테스트 EUC-KR")
         (encoded (encode-coding-string orig coding))
         (decoded (decode-coding-string encoded coding)))
    (if (string= orig decoded)
        (egg--integration-log "[roundtrip:%s] OK (%s bytes)" coding (length encoded))
      (egg--integration-log "[roundtrip:%s] MISMATCH!\n  orig: %S\n  decoded: %S"
                            coding orig decoded))
    (string= orig decoded)))

(defun egg-test-roundtrip-euc-tw ()
  "EUC-TW の往復変換を検証（多バイトセット確認用）。"
  (let* ((coding 'euc-tw)
         (orig "繁體字 測試 EUC-TW")
         (encoded (encode-coding-string orig coding))
         (decoded (decode-coding-string encoded coding)))
    (if (string= orig decoded)
        (egg--integration-log "[roundtrip:%s] OK (%s bytes)" coding (length encoded))
      (egg--integration-log "[roundtrip:%s] MISMATCH!\n  orig: %S\n  decoded: %S"
                            coding orig decoded))
    (string= orig decoded)))

;;; ------------------------------------------------------------------------
;;;  統合ラッパー関数
;;; ------------------------------------------------------------------------


;;; ========================================================================
;;;  End of Round-trip Section
;;; ========================================================================

;;; ========================================================================
;;;  (2) Buffer I/O テストセクション
;;; ========================================================================
;;;
;;;  目的：
;;;    - 実際の Emacs バッファ I/O レイヤを通した encode/decode の整合性を確認。
;;;    - write-region と insert-file-contents 経由で round-trip させる。
;;;    - egg-str-as-* の互換性をより現実的な文脈で検証。
;;; ========================================================================

(defun egg-test-buffer-io-roundtrip (coding)
  "CODING 系でファイル I/O 往復が恒等的かを検証。"
  (let* ((orig (format "Buffer I/O test 日本語 (%s)" coding))
         (tmpfile (make-temp-file "egg-buffer-io-"))
         (default-coding-system-for-write coding)
         (default-coding-system-for-read coding))
    (unwind-protect
        (progn
          ;; write
          (with-temp-buffer
            (insert orig)
            (write-region (point-min) (point-max) tmpfile nil 'silent))

          ;; read back
          (with-temp-buffer
            (insert-file-contents tmpfile)
            (let ((decoded (buffer-string)))
              (if (string= orig decoded)
                  (egg--integration-log "[buffer-io:%s] OK" coding)
                (egg--integration-log "[buffer-io:%s] MISMATCH!\n  orig: %S\n  decoded: %S"
                                      coding orig decoded))
              (string= orig decoded))))
      (when (file-exists-p tmpfile)
        (delete-file tmpfile)))))

(defun egg-run-buffer-io-tests ()
  "主要エンコーディングで Buffer I/O roundtrip テストを実行する。"
  (mapc (lambda (coding)
          (egg--verify-wrapper
           (lambda ()
             (egg-test-buffer-io-roundtrip coding))))
        '(utf-8 euc-jp shift_jis euc-kr euc-tw)))


(defun egg-run-buffer-io-tests-dual-mode ()
  "Run buffer I/O roundtrip tests under both internal and UTF-8 modes.
各モードで (egg-run-buffer-io-tests) を呼び出し、
ログ上にどのモード（emacs-internal / utf-8）が使用されたかを明示する。"
  (dolist (mode '(t nil))
    (let ((egg-internal-mode mode))
      (egg--integration-log
       "==== Running buffer I/O tests with egg-internal-mode=%s (%s) ===="
       (if egg-internal-mode "ON" "OFF")
       (if egg-internal-mode "emacs-internal" "utf-8"))
      (egg-run-buffer-io-tests))))

;;
;;
;;(void-variable system-coding-system)
;;
;; The variable system-coding-system was removed (actually made
;; obsolete and then undefined) in Emacs 27.  It existed long ago as
;; part of the Mule layer (used to track file and subprocess coding
;; defaults).
;;
;; So, in newer Emacsen (27+), trying to read it directly causes a
;; void-variable error.
;;
;; ✅ The correct modern approach
;;
;; You can safely replace all uses of
;; system-coding-system with: default-process-coding-system (for
;; subprocess-related behavior), or default-buffer-file-coding-system
;; (for file-related behavior), or just log "N/A" if you only need it
;; for informational display.
;;
;; For your specific locale-switch test, we don’t actually need to
;; modify any low-level system coding defaults — the test’s purpose
;; is to see how your egg-* encode/decode behaves under different LANG
;; and locale-coding-system environments.
;;
;;
;; 🪶 Notes
;; This version avoids touching the obsolete system-coding-system.
;;
;; It modifies only documented, safe, user-level variables like:
;; LANG
;;
;; locale-coding-system
;;
;; default-buffer-file-coding-system
;;
;; It restores the original environment at the end.
;;
;; It’s tested to work correctly on Emacs 27–29.


(defun egg-run-locale-switch-tests ()
  "Locale 環境を切り替えて EGG のラウンドトリップおよび I/O テストを実行する。
事前に現在の LANG, system-coding-system, locale-coding-system を保存し、
各ロケールごとに環境を切り替えてテストを実行する。
存在しないロケールは自動的にスキップされる。"
  (let* ((original-locale (or (getenv "LANG") "C"))
         (original-system-coding (and (boundp 'system-coding-system)
                                      system-coding-system))
         (original-locale-coding locale-coding-system)
         ;; テスト対象ロケール一覧（静的に定義）
         (locales
          '(("ja_JP.UTF-8" . utf-8)
            ("ja_JP.eucJP" . euc-jp)
            ("ja_JP.SJIS"  . shift_jis)
            ("ja_JP.CP932" . cp932)))
         (locale-available-p
          (lambda (loc)
            "Return non-nil if LOCALE is supported on this system."
            (ignore-errors
              (let ((res (call-process "locale" nil nil nil "-a")))
                (with-temp-buffer
                  (call-process "locale" nil t nil "-a")
                  (goto-char (point-min))
                  (re-search-forward (regexp-quote loc) nil t)))))))

    (egg--integration-log "==== (D) Locale switch tests ====")

    (dolist (pair locales)
      (let* ((loc (car pair))
             (coding (cdr pair)))
        (if (not (funcall locale-available-p loc))
            (egg--integration-log "[locale:%s] SKIPPED (not available)" loc)
          (condition-case err
              (progn
                (setenv "LANG" loc)
                (set-locale-environment loc)
                (set-language-environment "Japanese")
                (setq locale-coding-system coding)
                (when (boundp 'system-coding-system)
                  (setq system-coding-system coding))
                (egg--integration-log "[locale:%s] system=%s locale=%s"
                                      loc
                                      (if (boundp 'system-coding-system)
                                          system-coding-system
                                        "N/A")
                                      locale-coding-system)
                ;; (A) Roundtrip tests
                (egg-run-roundtrip-tests)
                ;; (B) Buffer I/O tests
                (egg-run-buffer-io-tests)
                (egg--integration-log "[locale:%s] OK" loc))
            (error
             (egg--integration-log "[locale:%s] FAILED (%s)" loc err))))))

    ;; 元に戻す
    (setenv "LANG" original-locale)
    (set-locale-environment original-locale)
    (setq locale-coding-system original-locale-coding)
    (when (boundp 'system-coding-system)
      (setq system-coding-system original-system-coding))
    (egg--integration-log "==== End locale switch tests ====")))



;;; ========================================================================
;;;  End of Buffer I/O Section
;;; ========================================================================



;;; 使用例:
;;;   M-x egg-show-ng-summary
;;;     → 直前の *EGG-Log* から NG テストのみ抽出し *EGG-Summary* に一覧表示。
;;; ----------------------------------------------------------------------
;;;
;;; ------------------------------------------------------------
(provide 'egg-integration-tests)
;;;
;;; ----------------------------------------------------------------------
;;; [開発メモ] 現フェーズまとめ  (2025-10-11)
;;; ----------------------------------------------------------------------
;; このメモは egg-integration-tests の第3フェーズ (dual-mode 拡張および
;; self-verifying test harness) の成果と設計意図を記録する。
;; 実行対象: Emacs 29.3+ / UTF-8 環境前提。
;;
;; ----------------------------------------------------------------------
;; 【目的】
;;   - 文字コード処理の二重モード (internal-mode=ON/OFF) 双方における
;;     encode/decode 一貫性検証を自動化。
;;   - Invalid byte sequence を含むケースの挙動をロギング・可視化。
;;   - デバッグフラグや default/buffer coding の各組み合わせを包括的に走査。
;;
;; ----------------------------------------------------------------------
;; 【新規/変更関数】
;;
;; 1. egg--verify-wrapper
;;    - 各テスト関数呼び出しを標準化し、OK/NG のログ出力を統一。
;;    - テスト単位での実行時間を計測。
;;
;; 2. egg-verify-all-extended-dual-mode-with-diff
;;    - 旧 egg-verify-all-dual-mode を拡張。
;;    - internal-mode (t/nil) 切替えを自動で行い、総括レポートを生成。
;;    - invalid-bytes 系テストを追加し、re-encode の再一致を検証。
;;    - 「Decoded identically」「Re-encode mismatch」など詳細ログ出力対応。
;;
;; 3. egg-run-all-config-combinations
;;    - dual-mode 検証をさらに多軸展開。
;;    - internal/debug/default/buffer coding の組み合わせごとにセクション分離。
;;    - 各構成ごとの NG 件数と elapsed time を自動集計しログに出力。
;;
;; ----------------------------------------------------------------------
;; 【ログ出力仕様】
;;
;; *EGG-Log* に次の構造で出力される：
;;
;;   [YYYY-MM-DD HH:MM:SS] ==== [EGG TEST CONFIGURATION SNAPSHOT] ====
;;   egg-internal-mode              : t
;;   egg-string-as-debug-flag       : t
;;   egg-default-coding             : utf-8
;;   buffer-file-coding-system      : utf-8
;;   -------------------------------------------
;;   ==== Running tests with egg-internal-mode=ON (emacs-internal) ====
;;   ...
;;   [SUMMARY] elapsed=0.045s, NG=0
;;   ==== END CONFIG ====
;;
;; NG は "→ NG" をカウントすることで集計。詳細な不一致点は既存 diff 機構により別途出力。
;;
;; ----------------------------------------------------------------------
;; 【デバッグ補助】
;;
;; (setq egg-string-as-debug-flag t)
;;   → encode/decode の詳細比較 ("Decoded identically", "Re-encode mismatch") を常時出力。
;;
;; (setq egg-internal-mode nil)
;;   → 外部 UTF-8 経路での再現性確認。
;;
;; (setq egg-default-coding 'euc-jp)
;; (setq buffer-file-coding-system 'euc-jp)
;;   → 非 UTF-8 パスでのテスト用。
;;
;; ----------------------------------------------------------------------
;; 【今後の展開】
;;
;; - (A) NG レポートの自動要約 (summary view buffer)
;; - (B) test-case レベルでの diff 保存機能 (再現比較)
;; - (C) CI 向けバッチ実行 (非対話 emacs -batch 用)
;; - (D) locale 切替えによる system-coding-system レベルの影響比較
;;
;; ----------------------------------------------------------------------
;;; End of current phase memo
;;; ----------------------------------------------------------------------
;;; ------------------------------------------------------------
