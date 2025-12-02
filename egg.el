;;; egg.el --- EGG Input Method Architecture -*- lexical-binding: nil -*-

;; Copyright (C) 1999-2015 Free Software Foundation, Inc
;;               2014, 2015 Mitsutoshi NAKANO <bkbin005@rinku.zaq.ne.jp>
;;               2015 Hiroki Sato <hrs@allbsd.org>

;; Author: NIIBE Yutaka <gniibe@chroot.org>
;;         KATAYAMA Yoshio <kate@pfu.co.jp>

;; Keywords: mule, multilingual, input method

;; This file is part of EGG.

;; EGG is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; EGG is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc.,
;; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

;;; Commentary:

;;; Code:

(defconst egg-version "4.0.6+2007-patch-for-define-coding-system+patch-for-emacs-24.3b-compatibility-change-for-30.1"
  "Version number for this version of Tamago.")

(defconst egg-tsunagi-version egg-version
  "Version number for this version of Tamago-tsunagi.")

(require 'cl-lib)

(require 'egg-edep)

(autoload 'egg-simple-input-method "egg-sim"
  "simple input method for Tamago 4." t)

(defgroup egg '((egg-default-language 'custom-variable)
                )
  "Tamago Version 4.xyz")
;(defgroup egg nil
;  "Tamago Version 5.")

(defcustom egg-mode-preference t
  "*Make Egg as modefull input method, if non-NIL."
  :group 'egg :type 'boolean)

(defvar egg-default-language)

(defvar egg-last-method-name nil)
(make-variable-buffer-local 'egg-last-method-name)
(put 'egg-last-method-name 'permanent-local t)

(defvar egg-mode-map-alist nil)
(defvar egg-sub-mode-map-alist nil)

(defmacro define-egg-mode-map (mode &rest initializer)
  (let ((map (intern (concat "egg-" (symbol-name mode) "-map")))
	(var (intern (concat "egg-" (symbol-name mode) "-mode")))
	(comment (concat (symbol-name mode) " keymap for EGG mode.")))
    `(progn
       (defvar ,map (let ((map (make-sparse-keymap)))
		      ,@initializer
		      map)
	 ,comment)
       (fset ',map ,map)
       (defvar ,var nil)
       (make-variable-buffer-local ',var)
       (put ',var 'permanent-local t)
       (or (assq ',var egg-mode-map-alist)
	   (setq egg-mode-map-alist (append egg-mode-map-alist
					    '((,var . ,map))))))))

(define-egg-mode-map modefull
  (define-key map "\C-^" 'egg-simple-input-method)
  (let ((i 33))
    (while (< i 127)
      (define-key map (vector i) 'egg-self-insert-char)
      (setq i (1+ i)))))

(define-egg-mode-map modeless
  (define-key map " " 'mlh-space-bar-backward-henkan)
  (define-key map "\C-^" 'egg-simple-input-method))

(defvar egg-enter/leave-fence-hook nil)

(defun egg-enter/leave-fence (&optional old new)
  (run-hooks 'egg-enter/leave-fence-hook))

(defvar egg-activated nil)
(make-variable-buffer-local 'egg-activated)
(put 'egg-activated 'permanent-local t)

(defun egg-activate-keymap ()
  (when (and egg-activated
	     (null (eq (car egg-sub-mode-map-alist)
		       (car minor-mode-overriding-map-alist))))
    (let ((alist (append egg-sub-mode-map-alist egg-mode-map-alist))
	  (overriding (copy-sequence minor-mode-overriding-map-alist)))
      (while alist
	(setq overriding (delq (assq (caar alist) overriding) overriding)
	      alist (cdr alist)))
      (setq minor-mode-overriding-map-alist (append egg-sub-mode-map-alist
						    overriding
						    egg-mode-map-alist)))))

(add-hook 'egg-enter/leave-fence-hook 'egg-activate-keymap t)

(defun egg-modify-fence (&rest arg)
  (add-hook 'post-command-hook 'egg-post-command-func))

(defun egg-post-command-func ()
  (run-hooks 'egg-enter/leave-fence-hook)
  (remove-hook 'post-command-hook 'egg-post-command-func))

(defvar egg-change-major-mode-buffer nil)

(defun egg-activate-keymap-after-command ()
  (while egg-change-major-mode-buffer
;    (save-excursion
;      (set-buffer (car egg-change-major-mode-buffer))
;      (egg-activate-keymap)
    (let ((buf (car egg-change-major-mode-buffer)))
      (if (buffer-live-p buf)
          (with-current-buffer buf
            (egg-activate-keymap)))
      (setq egg-change-major-mode-buffer (cdr egg-change-major-mode-buffer))))
  (remove-hook 'post-command-hook 'egg-activate-keymap-after-command))

(defun egg-change-major-mode-func ()
  (setq egg-change-major-mode-buffer (cons (current-buffer)
					   egg-change-major-mode-buffer))
  (add-hook 'post-command-hook 'egg-activate-keymap-after-command))

(add-hook 'change-major-mode-hook 'egg-change-major-mode-func)

;;;###autoload
(defun egg-mode (&rest arg)
  "Toggle EGG  mode.
\\[describe-bindings]
"
  (interactive "P")
  (if (null arg)
      ;; Turn off
      (unwind-protect
	  (progn
	    (its-exit-mode)
	    (egg-exit-conversion))
	(setq describe-current-input-method-function nil
	      egg-modefull-mode nil
	      egg-modeless-mode nil)
	(remove-hook 'input-method-activate-hook 'its-set-mode-line-title t)
	(force-mode-line-update))
    ;; Turn on
    (if (null (string= (car arg) egg-last-method-name))
	(progn
	  (funcall (nth 1 arg))
	  (setq egg-default-language its-current-language)))
    (egg-set-conversion-backend (nthcdr 2 arg))
    (egg-set-conversion-backend
     (list (assq its-current-language (nthcdr 2 arg))) t)
    (setq egg-last-method-name (car arg)
	  egg-activated t)
    (egg-activate-keymap)
    (if egg-mode-preference
	(progn
	  (setq egg-modefull-mode t)
	  (its-define-select-keys egg-modefull-map))
      (setq egg-modeless-mode t))
    ;;; PATCHED. inactivate-... => deactivate-curent-input-method-function
    ;(setq deactivate-current-input-method-function 'egg-mode)
    (set (if (boundp 'deactivate-current-input-method-function)
	     'deactivate-current-input-method-function
	   'inactivate-current-input-method-function)
	 #'egg-mode)
    (setq describe-current-input-method-function 'egg-help)
;   (if (<= emacs-major-version 23)
;      (make-local-hook 'input-method-activate-hook))
    (if (fboundp 'make-local-hook)
      (eval '(make-local-hook 'input-method-activate-hook)))
    (add-hook 'input-method-activate-hook 'its-set-mode-line-title nil t)
    (if (eq (selected-window) (minibuffer-window))
	(add-hook 'minibuffer-exit-hook 'egg-exit-from-minibuffer))
    (run-hooks 'egg-mode-hook)))

(defun egg-exit-from-minibuffer ()
  ;;; PATCHED. inactivate-... => deactivate-curent-input-method-function
; (deactivate-input-method)
  (if (fboundp 'deactivate-input-method)
      (deactivate-input-method)
    (inactivate-input-method))
  (if (<= (minibuffer-depth) 1)
      (remove-hook 'minibuffer-exit-hook 'egg-exit-from-minibuffer)))

(defvar egg-context nil)

(defun egg-self-insert-char ()
  (interactive)
  ;;; PATCHED APR 2013. last-command-char -> last-command-event
  ;(its-start last-command-event (and (eq last-command 'egg-use-context)
  ;				    egg-context)))
  (its-start (if (boundp 'last-command-event)
		 last-command-event
	       last-command-char)
	     (and (eq last-command 'egg-use-context)
				    egg-context)))

(defun egg-remove-all-text-properties (from to &optional object)
  (let ((p from)
	props prop)
    (while (< p to)
      (setq prop (text-properties-at p object))
      (while prop
	(unless (eq (car prop) 'composition)
	  (setq props (plist-put props (car prop) nil)))
	(setq prop (cddr prop)))
      (setq p (next-property-change p object to)))
    (remove-text-properties from to props object)))

(defun egg-setup-invisibility-spec ()
  (if (listp buffer-invisibility-spec)
      (unless (condition-case nil (memq 'egg buffer-invisibility-spec) (error))
	(setq buffer-invisibility-spec (cons 'egg buffer-invisibility-spec)))
    (unless (eq buffer-invisibility-spec t)
      (setq buffer-invisibility-spec (list 'egg buffer-invisibility-spec)))))

(defvar egg-mark-list nil)
(defvar egg-suppress-marking nil)

(defun egg-set-face (beg eng face &optional object)
  (let ((hook (get-text-property beg 'modification-hooks object)))
  (put face 'face face)
  (add-text-properties beg eng
		       (list 'category face
			     'egg-face t
			       'modification-hooks (cons 'egg-mark-modification
							 hook))
			 object)))

(defun egg-mark-modification (beg end)
  (if (and (null egg-suppress-marking)
	   (or (get-text-property beg 'egg-face)
	       (setq beg (next-single-property-change beg 'egg-face)))
	   (or (get-text-property (1- end) 'egg-face)
	       (setq end (previous-single-property-change end 'egg-face)))
	   (< beg end))
      (let ((list egg-mark-list)
	    (found 0)
	    pair mb me b e)
	(add-hook 'post-command-hook 'egg-redraw-face t)
	(setq list egg-mark-list)
	(while (and list (< found 2))
	  (setq pair (car list)
		list (cdr list)
		mb (car pair)
		me (cdr pair)
		b (marker-position mb)
		e (marker-position me))
	  (cond
	   ;; no overwrapping -- SKIP
	   ((or (null (eq (marker-buffer mb) (current-buffer)))
		(or (> beg e) (< end b))))
	   ;; completely included
	   ((and (>= beg b) (<= end e))
	    (setq found 3))
	   ;; partially overwrapping
	   (t
	    (set-marker mb nil)
	    (set-marker me nil)
	    (setq egg-mark-list (delete pair egg-mark-list)
		  beg (min beg b)
		  end (max end e)
		  found (1+ found)))))
	(if (< found 3)
	    (progn
	      (setq b (make-marker)
		    e (make-marker)
		    egg-mark-list (cons (cons b e) egg-mark-list))
	      (set-marker b beg)
	      (set-marker e end))))))

;;;
;;;inhibit-point-motion-hooks は、カーソルがテキストプロパティ
;;;point-entered や point-left に差し掛かったときに呼ばれるフックを無
;;;効化するための変数でした。
;;;
;;;でも egg-redraw-face の処理内容を見ると、実際にはカーソル移動に依存
;;;していない単なるフェイス削除処理なので、ここで
;;;inhibit-point-motion-hooks を立てる必要はなさそうです。
;;;
;;;Q? : 関数のなかに （goto-char ...) などがありますが、それはカーソルをう
;;;ごかしていることにはならないのですか？
;;;
;;;とても鋭いポイントです 👍

;;; 確かに egg-redraw-face の中には goto-char があり、バッファ内のポイ
;;; ント（カーソル位置）を移動しています。
;;;
;;; ここで問題になるのは？
;;; 
;;; Emacs にはテキストプロパティ point-entered / point-left があり、ポ
;;; イントがその範囲に入ったり出たりするたびにフックが走るという仕組み
;;; があります。
;;;
;;;inhibit-point-motion-hooks は、これらを一時的に止めるための変数でし
;;;た。
;;;
;;;つまり、もしバッファにそういうフックが付いていたら、goto-char でポ
;;;イントを動かすたびに余計な処理が呼ばれてしまうのを抑える目的だった
;;;可能性はあります。
;;;
;;;ただし…
;;;
;;;inhibit-point-motion-hooks 自体は Emacs 25 で obsolete。
;;;
;;;代わりに cursor-sensor-mode が導入されました。
;;;
;;; cursor-sensor-mode が有効になっていると、ポイント移動時に
;;; cursor-sensor-functions が走ります。
;;;
;;;それを一時的に無効化するには、(let ((cursor-sensor-inhibit t)) …) を使えます。
;;; 

(defun egg-redraw-face ()
  (let ((inhibit-read-only t)
        (inhibit-point-motion-hooks t) ; for Emacs <25
        (cursor-sensor-inhibit (if (boundp 'cursor-sensor-inhibit) t nil))
        (egg-suppress-marking t)
        (list egg-mark-list)
        (org-buffer (current-buffer))
        (org-point (point))
        mb me b e p)
    (setq egg-mark-list nil)
    (remove-hook 'post-command-hook 'egg-redraw-face)
    (while list
      (setq mb (car (car list))
            me (cdr (car list))
            list (cdr list))
      (when (marker-buffer mb)
        (set-buffer (marker-buffer mb))
        (let ((before-change-functions nil) (after-change-functions nil))
          (save-excursion
            (save-restriction
              (widen)
              (setq b (max mb (point-min))
                    e (min me (point-max)))
              (set-marker mb nil)
              (set-marker me nil)
              (while (< b e)
                (if (null (get-text-property b 'egg-face))
                    (setq b (next-single-property-change b 'egg-face nil e)))
                (setq p (next-single-property-change b 'egg-face nil e))
                (when (< b p)
                  (goto-char b)
                  (remove-text-properties 0 (- p b) '(face))
                  (setq b p))))))))
    (set-buffer org-buffer)
    (goto-char org-point)))

;
; Use the marker pair(s) in egg-mark-list
;
(defun egg-buffer-has-markers-at (point)
  (let ((list egg-mark-list)
	(found nil)
	beg  end  pair)
    (progn 
     (while (and (null found) list)
       (progn
	(setq pair (car list))
	(setq list (cdr list))
	(setq beg (car pair))
	(setq end (cdr pair))
	(setq found 
	      (cond 
	       ( (= (marker-position beg) position) 
		 t)
	       ( (= (marker-position end) position) 
		 t)
	       (t nil)))
	)) ; progn, while
     found ))) ;;; return flag value.


(defvar egg-messages nil)
(defvar egg-message-language-alist nil)

(defun egg-get-message (message)
  (let ((lang (or (cdr (assq egg-default-language egg-message-language-alist))
		  egg-default-language)))
    (or (nth 1 (assq message (cdr (assq lang egg-messages))))
	(nth 1 (assq message (cdr (assq nil egg-messages))))
	(error "EGG internal error: no such message: %s (%s)"
	       message egg-default-language))))

(defun egg-add-message (list)
  (let (l msg-l)
    (while list
      (setq l (car list))
      (or (setq msg-l (assq (car l) egg-messages))
	  (setq egg-messages (cons (list (car l)) egg-messages)
		msg-l (car egg-messages)))
      (mapcar
       (lambda (msg)
	 (setcdr msg-l (cons msg (delq (assq (car msg) msg-l) (cdr msg-l)))))
       (cdr l))
      (setq list (cdr list)))))

(defun egg-set-message-language-alist (alist)
  (let ((a alist))
    (while a
      (setq egg-message-language-alist
	    (delq (assq (caar a) egg-message-language-alist)
		  egg-message-language-alist))
      (setq a (cdr a)))
    (setq egg-message-language-alist
	  (append alist egg-message-language-alist))))

(put 'egg-error 'error-conditions '(error egg-error))
(put 'egg-error 'error-message "EGG error")

(defun egg-error (message &rest args)
  (if (symbolp message)
      (setq message (egg-get-message message)))
  (signal 'egg-error (list (apply 'format message args))))

;;;
;;; auto fill controll
;;;

(defun egg-do-auto-fill ()
  (if (and auto-fill-function (> (current-column) fill-column))
      (let ((ocolumn (current-column)))
	(funcall auto-fill-function)
	(while (and (< fill-column (current-column))
		    (< (current-column) ocolumn))
  	  (setq ocolumn (current-column))
	  (funcall auto-fill-function)))))

;;; to obtain the defuns of functions to which hooks are added
(cl-eval-when (eval load)
  (require 'its)
  (require 'menudiag)
  (require 'egg-mlh)
  (require 'egg-cnv)
  (require 'egg-com))

(add-hook 'kill-emacs-hook 'egg-kill-emacs-function)
(defun egg-kill-emacs-function ()
  (egg-finalize-backend))

;;; ========================================

;;; [PATCH-EGG-M1-CURSOR-EXIT | 2025-10-21 21:15 JST]
;;; -------------------------------------------------------------
;;;  Purpose:
;;;    Mode 1 behavior — cleanly end EGG/Tamago conversion
;;;    whenever the user moves the cursor outside the
;;;    active conversion region (by key or mouse).

;;; -------------------------------------------------------------
;;;  Section 1:  Region-tracking variables
;;; -------------------------------------------------------------
(defvar egg-conv-region-start nil
  "Buffer position of current conversion start.")
(defvar egg-conv-region-end nil
  "Buffer position of current conversion end.")
(defvar egg-conv-region-active nil
  "Non-nil while a conversion region is active.")

;;; -------------------------------------------------------------
;;;  Section 2:  Region activation and cleanup helpers
;;; -------------------------------------------------------------
(defun egg--activate-conv-region (start end)
  "Mark conversion as active between START and END."
  (setq egg-conv-region-start start
        egg-conv-region-end end
        egg-conv-region-active t)
  (when its-debug-enabled
    (its-debug-log "EGG-M1: activate region %d–%d" start end))
  (add-hook 'post-command-hook #'egg--check-cursor-outside-conv))

(defun egg--deactivate-conv-region ()
  "Clear conversion-tracking variables and remove the movement checker."
  (when its-debug-enabled
    (its-debug-log "EGG-M1: deactivate region %d–%d"
                   (or egg-conv-region-start -1)
                   (or egg-conv-region-end -1)))
  (setq egg-conv-region-start nil
        egg-conv-region-end nil
        egg-conv-region-active nil)
  (remove-hook 'post-command-hook #'egg--check-cursor-outside-conv))

;;; -------------------------------------------------------------
;;;  Section 3:  Cursor-movement watcher
;;; -------------------------------------------------------------
(defun egg--check-cursor-outside-conv ()
  "If point leaves the active conversion region, exit conversion cleanly."
  (when (and egg-conv-region-active
             (or (< (point) egg-conv-region-start)
                 (> (point) egg-conv-region-end)))
    (when its-debug-enabled
      (its-debug-log "EGG-M1: point %d outside [%d,%d] → auto-exit"
                     (point) egg-conv-region-start egg-conv-region-end))
    (condition-case err
        (progn
          (egg-exit-conversion)
          (its-debug-log "EGG-M1: auto-exit completed."))
      (error
       (its-debug-log "EGG-M1: auto-exit error → %S" err)))
    (egg--deactivate-conv-region)))

;;; -------------------------------------------------------------
;;;  Section 4:  Integration points
;;; -------------------------------------------------------------
;;;  (A)  In `egg-start-conversion' (or equivalent), insert:
;;;       (egg--activate-conv-region start end)
;;;
;;;  (B)  In `egg-end-conversion' *and* `egg-exit-conversion', insert:
;;;       (egg--deactivate-conv-region)
;;;
;;;  Both additions should appear after the region’s text
;;;  properties are finalized or removed, respectively.
;;; -------------------------------------------------------------

;;; [END OF PATCH-EGG-M1-CURSOR-EXIT]

(provide 'egg)

;;; egg.el ends here
