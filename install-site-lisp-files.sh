:
#
set -evx
PATH=/usr/bin:$PATH
make
make install
make clean
pushd /usr/local/share/emacs/site-lisp/egg || exit 6
echo
echo "Do we have .elc files?"
echo
ls -R
rm -f *.elc
rm -f egg/*.elc
rm -f its/*.elc
ls -R


