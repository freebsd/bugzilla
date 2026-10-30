# What is freebsd/bugzilla?

freebsd/bugzilla is a set of changes and extensions for Bugzilla being used
by the FreeBSD project. Those usually map a Bugzilla source package layout
in a 1:1 fashion.

# How do I use it?

freebsd/bugzilla will refer to a certain bugzilla package from the FreeBSD
ports, usually the latest stable one (devel/bugzilla52 as of now).

Thus, if you install devel/bugzilla52, you can simply copy
freebsd/bugzilla over ${PREFIX}/www/bugzilla to have a Bugzilla implementation
that resembles what the FreeBSD project uses at
https://bugs.freebsd.org/bugzilla.

In short:

* cd /usr/ports/devel/bugzilla52 && make install clean
* Download the latest stable freebsd/bugzilla release from https://github.com/freebsd/bugzilla
* tar -C /usr/local/www/bugzilla --strip-components=1 -xjvf (filename).tar.gz
* cd /usr/local/www/bugzilla && checksetup.pl
