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

Some features were either missing or used incorrctly and were fixed
during 2013 changes.

But emacs kept on evolving.
Emacs 23 and 24 introduced a few serious changes in the category
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
     WORKSFOME: I think the above was due to an incorrect initial
     value which 
     I added to an integer array, etc. and
     misue of macros, or rather the TOO eager macroexpand of emacs 30.2

Only in ~/repos/tamago-tsunagi/its: jiskana.el


Files only in my older modified package.

      Omitted.

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
   I modified the vector size for obarray/hash table to be prime numbers

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
     
