# check_files

Check some properties (age, size, count) on files, in a given directory on POSIX systems. Designed to be portable on any UNIX-like system.

It counts regular files by default but can also search for directories and symlinks.

The different constraints are the following :

 - Age of each file
 - Size of each file
 - Number of files
 - Space used by the directory
 
For space used and size of file the unit is fixed and is kilo-bytes.

Although the script is portable and should run unmodified on any *NIX some functionnalities are only available if _find_ is GNU find.
