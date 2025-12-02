:
#
# list duplicate defun
#
# for each such symbol
#    One needs to identify what definition is relevant by checking
#    (symbol-file definedname)
#    comment out the defun that is NOT loaded initially.
#


FILES="egg-string-as-mode-test.el egg-cnv.el egg-integration-verify.el egg-integration-tests.el egg-compatibility.el egg-integration-dual-diff.el verify-egg-string-as.el"
patterns="(defmacro|defconst|defvar|require|provide|defun)"

# FILES="*.el egg/*.el its/*.el"
patterns="(defmacro|defconst|defun|defvar)"

# ": [\s\t* ("-> ":("
# Sort the output using the second key
#
# verify-egg-string-as.el:(defun egg-verify--append-report (type status str detail)
# verify-egg-string-as.el:   (t "Unclassified mismatch (manual inspection required)")
# egg-compatibility.el:;; (defun egg--verify-string-conversion (old new func &optional 
# --->
# verify-egg-string-as.el:(defun egg-verify--append-report (type status str detail)
# verify-egg-string-as.el:(t "Unclassified mismatch (manual inspection required)")
# egg-compatibility.el:;; (defun egg--verify-string-conversion (old new func &optional 
# 

# SEDCMD="s/:[\\t\\s][\\t\\s]*\\(/:\\(/"
SEDCMD='s/:[\\t ][\\t ]*\\(/:\\(/'
SEDCMD='s/:[\\t ][\\t ]*(/:(/'
# echo "$SEDCMD"

# second sed command is to eliminated commented out lines
egrep $patterns  $FILES | sed  -e "$SEDCMD" -e '/[:][;]/d' | \
    sort -k 2 | gawk '{ printf("%-45s:%s\n", $2, $0); }' > /tmp/t-dup.list
echo
gawk 'BEGIN { f=""; }  {if ($1==f) printf("DUP:%s\n(symbol-file (quote %s))\n", $1,$1); f=$1;}' /tmp/t-dup.list
echo
cat /tmp/t-dup.list




 


