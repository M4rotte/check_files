# check_files

Check some properties (age, size, count, used space) on files, in a given directory on POSIX systems. Designed to be portable on any UNIX-like system.

It counts regular files by default but can also search for directories and symlinks.

The different constraints are the following :

 - Age of each file
 - Number of files
 - Size of each file
 - Space used by files
 
For space used and size of file the unit is fixed and is kilo-bytes.

More than one constraint may be specified (min and/or max), they will be checked in this order (age, number, size, used).

Although the script is portable and should run unmodified on any *NIX, some functionnalities are only available if _find_ is GNU find.
