;; egg-compatibility -*- lexical-binding: nil -*-
;;
;;
;;
;; | 操作                             | 効果                           |
;; | ------------------------------ | ---------------------------- |
;; | `(egg-toggle-internal-mode)`   | ON/OFFをトグル                   |
;; | `(egg-toggle-internal-mode 1)` | 強制的にON (`emacs-internal`を使う) |
;; | `(egg-toggle-internal-mode 0)` | 強制的にOFF (`utf-8`を使う)         |
;; | `(setq egg-internal-mode nil)` | 直接切り替えも可                     |
;;

(defvar egg-internal-mode t
  "If non-nil, prefer legacy EGG internal coding ('emacs-internal').
When nil, prefer 'utf-8' as the default coding system.
This allows switching between old-style Tamago/EUC behavior and
modern UTF-8 operation easily.")

(defun egg-toggle-internal-mode (&optional arg)
  "Toggle or explicitly set `egg-internal-mode`.

If ARG is positive or non-nil, enable legacy internal mode
(`emacs-internal` coding).  If ARG is zero or negative, disable it
and prefer UTF-8.  When called interactively without prefix,
toggle the current mode.

This function updates `egg-internal-mode` and shows the new state."
  (interactive "P")
  (setq egg-internal-mode
        (if (null arg)
            (not egg-internal-mode)
          (> (prefix-numeric-value arg) 0)))
  (message "[EGG] internal-mode now %s"
           (if egg-internal-mode "ON (emacs-internal)" "OFF (utf-8)"))
  egg-internal-mode)


;;;
;;;
;;; 

(defvar egg-string-as-strict-mode t
  "If non-nil, raise errors when encountering nonrepresentable strings.
If nil, log and return nil instead (used for integration testing).")

(defvar egg-compat-check-strict t
  "非nilなら新旧APIの差異をエラーにする。nilなら警告のみ。")

(defvar egg-string-as-debug-flag t
  "If non-nil, enable verbose logging and buffer traces for string-as tests.
When t, internal conversion steps, coding decisions, and buffer contents
are printed to *EGG-Log* or *Messages* for debugging purposes.")

(defun egg--check-consistency (old new coding-system context)
  "OLD=旧APIの結果, NEW=新APIの結果, CODING-SYSTEM=指定, CONTEXT=場所の説明。"
  (unless (equal old new)
    (if egg-compat-check-strict
        (error "[egg-compat] Inconsistent result in %s with %s" context coding-system)
      (warn "[egg-compat] Difference detected in %s (coding=%s). Using OLD result."
            context coding-system)))
  old)

(defun egg-decode-euc-jp (str &optional context)
  (let ((old (string-as-unibyte str))
        (new (encode-coding-string str 'euc-jp)))
    (egg--check-consistency old new 'euc-jp (or context "EUC-JP decode"))))

(defun egg-decode-euc-cn (str &optional context)
  (let ((old (string-as-unibyte str))
        (new (encode-coding-string str 'euc-cn)))
    (egg--check-consistency old new 'euc-cn (or context "EUC-CN decode"))))

(defun egg-decode-utf8 (str &optional context)
  (let ((old (string-as-unibyte str))
        (new (encode-coding-string str 'utf-8)))
    (egg--check-consistency old new 'utf-8 (or context "UTF-8 decode"))))

(defun egg-decode-binary (str &optional context)
  (let ((old (string-as-unibyte str))
        (new (encode-coding-string str 'egg-binary)))
    (egg--check-consistency old new 'egg-binary (or context "egg-binary decode"))))

;; ---

(defun egg-encode-euc-jp (str &optional context)
  "旧API string-as-multibyte vs 新API decode-coding-string (EUC-JP)."
  (let ((old (string-as-multibyte str))
        (new (decode-coding-string str 'euc-jp)))
    (egg--check-consistency old new 'euc-jp (or context "EUC-JP encode"))))

(defun egg-encode-euc-cn (str &optional context)
  "旧API string-as-multibyte vs 新API decode-coding-string (EUC-CN)."
  (let ((old (string-as-multibyte str))
        (new (decode-coding-string str 'euc-cn)))
    (egg--check-consistency old new 'euc-cn (or context "EUC-CN encode"))))

(defun egg-encode-utf8 (str &optional context)
  "旧API string-as-multibyte vs 新API decode-coding-string (UTF-8)."
  (let ((old (string-as-multibyte str))
        (new (decode-coding-string str 'utf-8)))
    (egg--check-consistency old new 'utf-8 (or context "UTF-8 encode"))))

(defun egg-encode-binary (str &optional context)
  "旧API string-as-multibyte vs 新API decode-coding-string (egg-binary)."
  (let ((old (string-as-multibyte str))
        (new (decode-coding-string str 'egg-binary)))
    (egg--check-consistency old new 'egg-binary (or context "egg-binary encode"))))

;;;

;;;=========================================================
;;; Backward-compatible wrappers with strict debug flag
;;;=========================================================

                                        ;| 状況                                 | 処理内容
                                        ;| ----------------------------------  | ----------------------------------------------------- |
                                        ;| `egg-string-as-debug-flag` = `nil`  | 旧 `string-as-*` の結果をそのまま返す（安全・従来通り）            |
                                        ;| `egg-string-as-debug-flag` ≠ `nil`  | 新旧結果を比較し、異なれば `message` で詳細を出して `error` を投げる |
                                        ;| `decode/encode-coding-string` 未定義  | `string-as-*` のみ使用、互換保持                               |
                                        ;| `coding-system` 未指定                | `buffer-file-coding-system` → `'emacs-internal` の順で推定 |
                                        ;
;;;=========================================================
;;; Backward-compatible wrappers with strict debug flag
;;;=========================================================


;; OLD not so rich and obsolete
;;(defun egg-string-as-multibyte (str &optional coding-system)
;;  "Backward-compatible replacement for `string-as-multibyte'.
;;If `egg-string-as-debug-flag' is non-nil, compare the result of
;;`string-as-multibyte' and `decode-coding-string'.  If they differ,
;;signal an error (after printing a warning message)."
;;  (let* ((legacy (if (fboundp 'string-as-multibyte)
;;                     (string-as-multibyte str)
;;                   str))
;;         (cs (or coding-system
;;                 (and (boundp 'buffer-file-coding-system)
;;                      buffer-file-coding-system)
;;                 'emacs-internal))
;;         (new (and (fboundp 'decode-coding-string)
;;                   (decode-coding-string str cs)))
;;         (mismatch (and new (not (equal legacy new)))))
;;    (when (and egg-string-as-debug-flag mismatch)
;;      (message "EGG DEBUG: mismatch detected in egg-string-as-multibyte.")
;;      (message "  coding-system: %S" cs)
;;      (message "  original: %S" (substring str 0 (min 40 (length str))))
;;      (message "  legacy:   %S" (substring legacy 0 (min 40 (length legacy))))
;;      (message "  new:      %S" (substring new 0 (min 40 (length new))))
;;      (error "egg-string-as-multibyte: result mismatch detected"))
;;    legacy))
                                        ;
;; OLD Obsolete
;;(defun egg-string-as-unibyte (str &optional coding-system)
;;  "Backward-compatible replacement for `string-as-unibyte'.
;;If `egg-string-as-debug-flag' is non-nil, compare the result of
;;`string-as-unibyte' and `encode-coding-string'.  If they differ,
;;signal an error (after printing a warning message)."
;;  (let* ((legacy (if (fboundp 'string-as-unibyte)
;;                     (string-as-unibyte str)
;;                   str))
;;         (cs (or coding-system
;;                 (and (boundp 'buffer-file-coding-system)
;;                      buffer-file-coding-system)
;;                 'emacs-internal))
;;         (new (and (fboundp 'encode-coding-string)
;;                   (encode-coding-string str cs)))
;;         (mismatch (and new (not (equal legacy new)))))
;;    (when (and egg-string-as-debug-flag mismatch)
;;      (message "EGG DEBUG: mismatch detected in egg-string-as-unibyte.")
;;      (message "  coding-system: %S" cs)
;;      (message "  original: %S" (substring str 0 (min 40 (length str))))
;;      (message "  legacy:   %S" (substring legacy 0 (min 40 (length legacy))))
;;      (message "  new:      %S" (substring new 0 (min 40 (length new))))
;;      (error "egg-string-as-unibyte: result mismatch detected"))
;;    legacy))

;;; -----

;;; helper 関数をつくって、そちらでチェックなどをするようにして、ロジッ
;;; クをオープンコーディングしないようにして見てもらえますか。さきほど
;;; の comm-unpack-u8-string の確認しているところも、その関数を呼び出
;;; して値をつかわないでエラーが無いことだけを確認すればいいと思います。

;;; とても良い考えです。各関数に同じような「旧API比較」「hexダンプ」
;;; 「デバッグ時のerror出力」ロジックを毎回オープンコーディングするの
;;; は冗長ですし、保守性も下がります。以下のように 共通ヘルパー関数
;;; egg-verify-string-conversion を定義し、全関数からそれを呼ぶように
;;; 整理する形を提案します。

(defun egg-verify-string-conversion (old new func-name &optional extra-info)
  "Compare OLD and NEW string conversion results for debugging.
If `egg-string-as-debug-flag' is non-nil and OLD and NEW differ,
report mismatch with FUNC-NAME and raise error.  EXTRA-INFO can be
used to add coding system or type hint text."
  (when (and (boundp 'egg-string-as-debug-flag)
             egg-string-as-debug-flag
             (stringp old) (stringp new)
             (not (string= old new)))
    (let* ((maxlen 200)
           (hex (mapconcat (lambda (n) (format "%02x" n))
                           (mapcar #'identity (string-to-list
                                               (substring old 0 (min (length old) 32))))
                           " ")))
      (message "[EGG-DEBUG] %s mismatch%s len=%d hex=%s"
               func-name
               (if extra-info (format " (%s)" extra-info) "")
               (length old)
               hex)
      (error "[EGG-DEBUG] %s: string conversion mismatch%s"
             func-name (if extra-info (format " (%s)" extra-info) "")))))


;; ---


;; ---
;; Use the defun later in this file.
;;(defun egg-string-as-multibyte-with-check (str func-name &optional extra-info)
;;  "Return multibyte STR, checking consistency with legacy `string-as-multibyte'."
;;  (let* ((new (egg-string-as-multibyte str))
;;         (old (and (fboundp 'string-as-multibyte)
;;                   (ignore-errors (string-as-multibyte str)))))
;;    (egg--verify-string-conversion old new func-name extra-info)
;;    new))

;;(defun egg-string-as-unibyte-with-check (str func-name &optional extra-info)
;;  "Return unibyte STR, checking consistency with legacy `string-as-unibyte'."
;;  (let* ((new (egg-string-as-unibyte str))
;;         (old (and (fboundp 'string-as-unibyte)
;;                   (ignore-errors (string-as-unibyte str)))))
;;    (egg--verify-string-conversion old new func-name extra-info)
;;    new))

;;; #### ========================================
;;; ===============================================================
;;; egg-string conversion helpers with legacy API verification
;;; ===============================================================


;;
;; Note TWO CONSECUTIVE "--" in the following function's name.
;;
(defun egg--verify-string-conversion (old new func-name &optional extra-info)
  "Compare OLD and NEW string conversion results for debugging.
If `egg-string-as-debug-flag' is non-nil and OLD and NEW differ,
report mismatch with FUNC-NAME and raise error.  EXTRA-INFO can
contain extra diagnostic text."
  (when (and (boundp 'egg-string-as-debug-flag)
             egg-string-as-debug-flag
             (stringp old) (stringp new)
             (not (string= old new)))
    (let* ((maxlen 200)
           (hex (mapconcat (lambda (n) (format "%02x" n))
                           (mapcar #'identity
                                   (string-to-list
                                    (substring old 0 (min (length old) 32))))
                           " ")))
      (message "[EGG-DEBUG] %s mismatch%s len=%d hex=%s"
               func-name
               (if extra-info (format " (%s)" extra-info) "")
               (length old)
               hex)
      (error "[EGG-DEBUG] %s: string conversion mismatch%s"
             func-name (if extra-info (format " (%s)" extra-info) "")))))

(defun egg-string-as-multibyte-with-check (str func-name &optional extra-info)
  "Return multibyte STR, checking consistency with legacy `string-as-multibyte'."
  (let* ((new (egg-string-as-multibyte str))
         (old (and (fboundp 'string-as-multibyte)
                   (ignore-errors (string-as-multibyte str)))))
    (egg--verify-string-conversion old new func-name extra-info)
    new))

(defun egg-string-as-unibyte-with-check (str func-name &optional extra-info)
  "Return unibyte STR, checking consistency with legacy `string-as-unibyte'."
  (let* ((new (egg-string-as-unibyte str))
         (old (and (fboundp 'string-as-unibyte)
                   (ignore-errors (string-as-unibyte str)))))
    (egg--verify-string-conversion old new func-name extra-info)
    new))

;;;
;;; 次の関数は存在しないぞ？ FIXME
;;;
(defun decode-fixed-euc-china (beg end type)
  (let ((str (decode-fixed-euc-china-region beg end type)))
    (egg-string-as-unibyte-with-check
     str "decode-fixed-euc-china"
     (format "type=%s" type))))

;;;
;;; 
;;;

;;; Compatibility wrappers for string-as-*/decode/encode-coding-string
;;;
;; Provide egg-string-as-multibyte / egg-string-as-unibyte that:
;; - Prefer decode/encode-coding-string with an explicit coding-system when available.
;; - If coding argument is nil, fall back to `buffer-file-coding-system' when meaningful.
;; - If older API exists (string-as-multibyte / string-as-unibyte), compare results.
;;   * If they differ and `egg-string-as-debug-flag' is non-nil => signal error (strict).
;;   * Otherwise emit a warning message and return the old-API result to preserve behavior.


(defun egg--choose-coding (coding)
  "Return a coding system for string conversion within EGG.
If CODING is non-nil, return it.  Otherwise choose based on
`buffer-file-coding-system` or `egg-internal-mode`."
  (or coding
      (and (boundp 'buffer-file-coding-system)
           buffer-file-coding-system)
      (if egg-internal-mode
          'emacs-internal
        'utf-8)))

;; older definition has better and complete format.
;; (defun egg--verify-string-conversion (old new func &optional coding note)
;;  "Compare OLD and NEW conversion results for FUNC.
;;If equal return NEW.  If differ then either signal (debug mode) or warn and
;;return OLD to preserve legacy behavior."
;;  (if (equal old new)
;;      new
;;    (let ((msg (format "egg: %s: conversion mismatch coding=%S note=%S\n  old=%S\n  new=%S"
;;                       func coding note old new)))
;;      (if egg-string-as-debug-flag
;;          (error "%s" msg)
;;        (message "%s" msg)
;;        ;; fall back to old result if available, otherwise use new
;;        (or old new)))))


;;
;; buffer-file-coding system は egg--choose-condig で
;; 参照して、 coding system の利用を判断している。
;; 

(defun egg-string-as-multibyte (string &optional _dummy)
  "EGG-safe replacement for `string-as-multibyte'.
When `egg-string-as-debug-flag' is non-nil, also compare result with the original function
to detect divergence."
  (if (not (stringp string))
      (error "egg-string-as-multibyte: argument not a string: %S" string)
    (let* ((new-result
            ;; 置換関数の本体（安全処理）
            (condition-case err
                (decode-coding-string (encode-coding-string string 'binary) 'utf-8)
              (error
               (when egg-string-as-debug-flag
                 (egg--debug-log "ERROR during new decode: %S" err))
               nil)))
           (old-result
            ;; Emacs に旧関数がある場合だけ比較する
            (when (and egg-string-as-debug-flag
                       (fboundp 'string-as-multibyte))
              (condition-case err
                  (string-as-multibyte string)
                (error
                 (egg--debug-log "OLD function raised error: %S" err)
                 nil)))))
      ;; 比較フェーズ
      (when (and egg-string-as-debug-flag old-result)
        (unless (equal new-result old-result)
          (egg--debug-log "[MISMATCH:VALUE] old=%S new=%S" old-result new-result)))
      new-result)))


(defun egg-string-as-unibyte (str &optional coding)
  "Backwards-compatible replacement for `string-as-unibyte'.
If CODING is non-nil it specifies the coding to use for encode-coding-string.
If `encode-coding-string' is available use it; else fall back to
`string-as-unibyte'.  On mismatch consult `egg-string-as-debug-flag'."
  (let* ((coding (egg--choose-coding coding))
         (new (if (fboundp 'encode-coding-string)
                  (encode-coding-string str coding)
                (string-as-unibyte str))) ; string-as-multibyte がない時は？ FIXME
         (old (and (fboundp 'string-as-unibyte)
                   (ignore-errors (string-as-unibyte str)))))
    (egg--verify-string-conversion old new "egg-string-as-unibyte" coding)))

;;;

(defun egg--debug-log (fmt &rest args)
  "Log formatted debug messages to *egg-debug* buffer."
  (when egg-string-as-debug-flag
    (with-current-buffer (get-buffer-create "*egg-debug*")
      (goto-char (point-max))
      (insert (apply #'format (concat fmt "\n") args)))))

;;; ----

;; too simple, use older and richer defun in the earlier part of this file.
;;
;;(defun egg-verify-string-conversion (old new fn context)
;;  "Compare OLD and NEW results; if different and `egg-string-as-debug-flag' is non-nil,
;;signal an error showing FN and CONTEXT."
;;  (when (and egg-string-as-debug-flag
;;             (not (equal old new)))
;;    (error "[egg-string-as-*] Mismatch detected in %s (%s): old and new conversion differ."
;;           fn context)))

;;
;; egg-string-as-multibyte without choice of coding system?!
;;(defun egg-string-as-multibyte (str)
;;  "Safer version of `string-as-multibyte' with backward compatibility check."
;;  (if (fboundp 'string-as-multibyte)
;;      (let* ((old (ignore-errors (string-as-multibyte str)))
;;             (new (decode-coding-string str buffer-file-coding-system)))
;;        (egg-verify-string-conversion old new "egg-string-as-multibyte" buffer-file-coding-system)
;;        (or old new str))
;;    str))

;; egg-string-as-unibyte without choice of coding system?!
;;(defun egg-string-as-unibyte (str)
;;  "Safer version of `string-as-unibyte' with backward compatibility check."
;;  (if (fboundp 'string-as-unibyte)
;;      (let* ((old (ignore-errors (string-as-unibyte str)))
;;             (new (encode-coding-string str buffer-file-coding-system)))
;;        (egg-verify-string-conversion old new "egg-string-as-unibyte" buffer-file-coding-system)
;;        (or old new str))
;;    str))

(provide 'egg-compatibility)
