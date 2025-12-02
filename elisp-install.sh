:
#
set -e
PATH=/usr/bin:$PATH
PATH=$HOME/repos/emacs-30.2/src/:$PATH
make clean
if make >& /tmp/t.compile
then
    : OK
else
    echo " ========================================"
    echo "Emacs-Lisp compilation error."
    echo " ----------------------------------------"
    tail -30 /tmp/t.compile
    exit 6
fi


if egrep -i multiple /tmp/t.compile
then
    echo " ========================================"
    echo "There were duplicates/multiple definitions. Emacs-Lisp compilation error."
    echo " ----------------------------------------"

    exit 6
fi

make install || exit 5

pushd /usr/local/share/emacs/site-lisp/egg || exit 6
echo
echo "Do we have .elc files?"
echo
ls -R
rm -f *.elc
rm -f egg/*.elc
rm -f its/*.elc
ls -R


