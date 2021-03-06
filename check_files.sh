#!/usr/bin/env sh

# set -x

# Default values

## General behaviour
VERBOSE=false
VERBOSITY=0
RETURN_CODE=3                # UNKNOWN : Status if anything goes wrong past this line.
ERROR_CODE=2                 # CRITICAL : Status on error (use option -W to set it to 1 (WARNING) instead)
MULTILINE=false              # Output on one line by defaut
ERROR_PREFIX=""              # No prefix for error message by default
OK_PREFIX=""                 # No prefix for OK message by default

## Search caracteristics
SEARCH_PATH="."              # If not provided, search current dir
SEARCH_TYPE='f'              # Search only regular files
SEARCH_AGE=$(false)             # Do not search for oldest and newest files
SEARCH_SIZE=$(false)            # Do not search for biggest and tiniest files
SEARCH_NAME_INCLUDE=""       # Only include files with this name from the count
SEARCH_NAME_EXCLUDE=""       # Exclude files with this name from the count
RECURSIVE=false              # Do not search in sub directories


## Age constraints
MIN_AGE=0
NEWER_FILES_NB=0
MAX_AGE=-1
OLDER_FILES_NB=0

## Count constraints
MIN_COUNT=0
MAX_COUNT=-1

## File size constraints
MIN_SIZE=0
SMALLER_FILES_NB=0
MAX_SIZE=-1
BIGGER_FILES_NB=0

## Disk usage constraints
MIN_USAGE=0
MAX_USAGE=-1

# What pager is available?
if env less 2>/dev/null
then pager='less'
else pager='more'
fi

# Help message
help_message() {
$pager <<EOF

$(basename "$0")

Check some properties on files in a given directory on POSIX systems.

Returns OK only if all the constraints are met.

Usage: $(basename "$0") [-vhrWlLM] [-a min-age] [-A max-age] [-n min-count] [-N max-count]
                        [-s min-size] [-S max-size] [-u min-usage] [-U max-usage]
                        [-t filetype]


 -d/--dir        <path>   Directory to search files in (default: ${SEARCH_PATH})
 -r/--recursive           Search recursively (default: $RECURSIVE)
 -t/--file-type  <string> Type of file to search for (default: $SEARCH_TYPE)
                          It may be any combination of the following letters:
                            
                            f : regular file
                            d : directory
                            l : symbolic link
                            
                          ex: 'fd' to search for regular files and directories.
                          
                          [NB]: '.' and '..' are counted when searching for directories in
                                non-recursive mode.
                          
                          To check if a directory is empty use: -tfdl -N2
                          
                                    -tfdl -N2
  
 -i/--include    <string> Search only for files with this name
 -x/--exclude    <string> Exclude files with this name
 
                          It's only possible to use at most one include and one exclude pattern.

                           
 -a/--min-age    <int>    Minimum age of the most recent file in minutes (default: ${MIN_AGE})
 -A/--max-age    <int>    Maximum age of the oldest file in minutes (default: ${MAX_AGE})
 -n/--min-count  <int>    Minimum number of files (default: ${MIN_COUNT})
 -N/--max-count  <int>    Maximum number of files (default: ${MAX_COUNT})
 -s/--min-size   <int>    Minimum size of each file in kB (default: ${MIN_SIZE})
 -S/--max-size   <int>    Maximum size of each file in kB (default: ${MAX_SIZE})
 -u/--min-usage  <int>    Minimum disk usage for files in kB (default: ${MIN_USAGE})
 -U/--max-usage  <int>    Maximum disk usage for files in kB (default: ${MAX_USAGE})

 -W/--warn-only           Return 1 (WARNING) instead of 2 (CRITICAL)
                          on constraints violation.
 -M/--multiline           Add line returns in the output
 -E/--error      <string> Prefix for error message (default: ${ERROR_PREFIX})
 -O/--ok         <string> Prefix for OK message (default: ${OK_PREFIX})                          
 -h/--help                Show this help
 -v/--verbose             Verbose mode
 
 The following options have no effect on systems without GNU find.
 
 -l/--search-age          Search for oldest and newest files. (default: $SEARCH_AGE)
 -L/--search-size         Search for biggest and smallest files. (default: $SEARCH_SIZE)
                          Those searches can be particulary long if used
                          in conjonction with -r (recursive).

EOF
}

# Check for positive integer
is_int() {
    case "$1" in
        (*[!0-9]*|'')
            false;
            ;;
        (*) true
    esac
}

# Arguments management #

## KISS way to handle long options
for arg in "${@}"; do
  shift
  case "${arg}" in
     ("--verbose")      set -- "${@}" "-v" ;;
     ("--help")         set -- "${@}" "-h" ;;
     ("--dir")          set -- "${@}" "-d" ;;
     ("--min-age")      set -- "${@}" "-a" ;;
     ("--max-age")      set -- "${@}" "-A" ;;
     ("--min-count")    set -- "${@}" "-n" ;;
     ("--max-count")    set -- "${@}" "-N" ;;
     ("--min-size")     set -- "${@}" "-s" ;;
     ("--max-size")     set -- "${@}" "-S" ;;
     ("--min-usage")    set -- "${@}" "-u" ;;
     ("--max-usage")    set -- "${@}" "-U" ;;
     ("--recursive")    set -- "${@}" "-r" ;;
     ("--file-type")    set -- "${@}" "-t" ;;
     ("--warn-only")    set -- "${@}" "-W" ;;
     ("--search-age")   set -- "${@}" "-l" ;;
     ("--search-size")  set -- "${@}" "-L" ;;
     ("--include")      set -- "${@}" "-i" ;;
     ("--exclude")      set -- "${@}" "-x" ;;
     ("--multiline")    set -- "${@}" "-M" ;;
     ("--error")        set -- "${@}" "-E" ;;
     ("--ok")           set -- "${@}" "-O" ;;
     (*)                set -- "${@}" "${arg}"
  esac
done;

## Parse command line options
while getopts "vWhMlLi:x:d:ra:A:n:N:s:S:u:U:t:E:O:" opt; do
    case "${opt}" in
        (v)
            VERBOSE=true;
            ;;
        (W)
            ERROR_CODE=1;
            ;;            
        (h)
            help_message;
            RETURN_CODE=3;
            exit "${RETURN_CODE}";
            ;;
        (d)
            if [ ! -d "${OPTARG}" ];
            then
                printf "\n%s\n" "Directory '${OPTARG}' not found."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                SEARCH_PATH="${OPTARG}";
            fi
            ;;
        (r)
            RECURSIVE=true;
            ;;
        (l)
            SEARCH_AGE=true;
            ;;
        (L)
            SEARCH_SIZE=true;
            ;;
        (i)
            SEARCH_NAME_INCLUDE="${OPTARG}";
            ;;
        (x)
            SEARCH_NAME_EXCLUDE="${OPTARG}";
            ;;
        (a)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -a expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MIN_AGE="${OPTARG}";
            fi
            ;;
        (A)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -A expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MAX_AGE="${OPTARG}";
            fi
            ;;
        (n)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -n expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MIN_COUNT="${OPTARG}";
            fi
            ;;
        (N)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -N expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MAX_COUNT="${OPTARG}";
            fi
            ;;
        (s)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -s expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MIN_SIZE="${OPTARG}";
            fi
            ;;
        (S)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -S expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MAX_SIZE="${OPTARG}";
            fi
            ;;
        (u)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -u expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MIN_USAGE="${OPTARG}";
            fi
            ;;
        (U)
            if ! is_int "${OPTARG}";
            then
                printf "\n%s\n" "Option -U expects a positive integer number as argument."
                RETURN_CODE=3;
                exit "${RETURN_CODE}";
            else
                MAX_USAGE="${OPTARG}";
            fi
            ;;
        (t)
            SEARCH_TYPE="${OPTARG}";
            ;;
        (M)
            MULTILINE=true
            ;;
        (E)
            ERROR_PREFIX="${OPTARG} - ";
            ;;
        (O)
            OK_PREFIX="${OPTARG} - ";
            ;;
        (\?)
            printf "%s\n" "Unsupported option...";
            help_message;
            RETURN_CODE=3
            exit "${RETURN_CODE}";
            ;;
    esac
done;

# Prepare the type clause for find
find_type_clause() {
# We rewrite $SEARCH_TYPE so the order is always the same in the output    
    case $1 in
        (f)                       SEARCH_TYPE="f";  FIND_TYPE_CLAUSE=" -type f " ;;
        (d)                       SEARCH_TYPE="d";  FIND_TYPE_CLAUSE=" -type d " ;;
        (l)                       SEARCH_TYPE="l";  FIND_TYPE_CLAUSE=" -type l " ;;
        (fd|df)                   SEARCH_TYPE="fd"; FIND_TYPE_CLAUSE=" \( -type f -o -type d \) " ;;
        (fl|lf)                   SEARCH_TYPE="fl"; FIND_TYPE_CLAUSE=" \( -type f -o -type l \) " ;;
        (ld|dl)                   SEARCH_TYPE="dl"; FIND_TYPE_CLAUSE=" \( -type l -o -type d \) " ;;
        (fld|fdl|ldf|lfd|dfl|dlf)
            SEARCH_TYPE="fdl"
            FIND_TYPE_CLAUSE=" \( -type l -o -type d -o -type f \) "
            ;;
        (*)
            (>&2 echo "Search type '${SEARCH_TYPE}' invalid, switching back to 'f'.")                       
            SEARCH_TYPE="f"; FIND_TYPE_CLAUSE=" -type f "
        ;;
    esac    
}
find_type_clause "${SEARCH_TYPE}"

# Prepare the name clause for find
find_name_clause() {
[ $(expr length $1) -gt 2 ] && FIND_NAME_CLAUSE=" -name "$1
[ $(expr length $1) -gt 2 -a $(expr length $2) -gt 2  ] && FIND_NAME_CLAUSE=${FIND_NAME_CLAUSE}" -a "
[ $(expr length $2) -gt 2  ] && FIND_NAME_CLAUSE=${FIND_NAME_CLAUSE}"\! -name  "$2
}
find_name_clause "'"${SEARCH_NAME_INCLUDE}"'" "'"${SEARCH_NAME_EXCLUDE}"'"

# Do find
do_find() {
cat <<EOF
find $@
EOF
}

# Count number of files newer than min-age
newer_files_nb() {
    NEWER_FILES_NB=$(eval "$(do_find "$1" "${FIND_TYPE_CLAUSE}" "${FIND_NAME_CLAUSE}" -mmin -"${MIN_AGE}")" |wc -l)
}

# Count number of files older than max-age
older_files_nb() {
    OLDER_FILES_NB=$(eval "$(do_find "$1" "${FIND_TYPE_CLAUSE}" "${FIND_NAME_CLAUSE}" -mmin +"${MAX_AGE}")" |wc -l)
}

# Count number of files smaller than min-size
smaller_files_nb() {
    SMALLER_FILES_NB=$(eval "$(do_find "$1" "${FIND_TYPE_CLAUSE}" "${FIND_NAME_CLAUSE}" -size -"${MIN_SIZE}"k)" |wc -l)
}

# Count number of files bigger than max-size
bigger_files_nb() {
    BIGGER_FILES_NB=$(eval "$(do_find "$1" "${FIND_TYPE_CLAUSE}" "${FIND_NAME_CLAUSE}" -size +"${MAX_SIZE}"k)" |wc -l)
}

# Measure disk usage
disk_usage() {
    DISK_USAGE=$(eval $(do_find "$1" -type f "${FIND_NAME_CLAUSE}" -exec 'du -sk {} \;' )| cut -f1 |\
                awk '{total=total+$1}END{print total}')
    [ -z "$DISK_USAGE" ] && DISK_USAGE=0            
}

# Check if we have the GNU implementation of find
is_gnu_find() {
    if [ $(find --version 2>/dev/null |grep -cw GNU) -gt 0 ]
    then
        true
    else
        false
    fi    
}

# Main script #

## Recursive?
if "$RECURSIVE"
then 
    tag="(R${SEARCH_TYPE}/i:'${SEARCH_NAME_INCLUDE}'x:'${SEARCH_NAME_EXCLUDE}')"
    search="$SEARCH_PATH"
else 
    tag="(${SEARCH_TYPE}/i:'${SEARCH_NAME_INCLUDE}'x:'${SEARCH_NAME_EXCLUDE}')"
    search="$SEARCH_PATH/* $SEARCH_PATH/.* -prune"
fi

# Multiline?
if "$MULTILINE"
then
    template='\n%s\n%s\n'
    sep='\n'
else
    template='%s %s\n'
    sep=' '
fi

## Count files
NB_FILES=$(eval "$(do_find "${search}" "${FIND_TYPE_CLAUSE}" "${FIND_NAME_CLAUSE}")" |wc -l)

## Perfdata
PERFDATA="nb_files=$(echo ${NB_FILES} |awk '{print $1}') "

# Search for oldest and newest files
[ is_gnu_find -a "$SEARCH_AGE" ] && {
    format="-printf '%Cs;%Cc;%p;%k kB;%Y\n'"
    by_age=$(eval $(do_find "$search" "${FIND_TYPE_CLAUSE}" "${FIND_NAME_CLAUSE}" ${format}) |sort -n |\
               awk 'BEGIN{FS=";"} {if (NR==1) print "(" $5 ")" $3 " (" $4 ") " $2} \
               END{print "(" $5 ")" $3 " (" $4 ") " $2}')
    oldest_file() {
    printf "$by_age\n" |head -1
    }
    newest_file() {
    printf "$by_age\n" |tail -1
    }
    OLDEST_MESSAGE=$(printf '%s\n' "[Oldest:$(oldest_file)]")
    NEWEST_MESSAGE=$(printf '%s\n' "[Newest:$(newest_file)]")
    OLDNEW_MESSAGE=$(printf "$template" "${OLDEST_MESSAGE}" "${NEWEST_MESSAGE}")
}

# Search for smallest and biggest files
[ is_gnu_find -a  "$SEARCH_SIZE" ] && {
    format="-printf '%s;%Cc;%p;%k kB;%Y\n'"
    by_size=$(eval $(do_find "$search" ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE} ${format}) |sort -n |\
               awk 'BEGIN{FS=";"} {if (NR==1) print "(" $5 ")" $3 " (" $4 ") " $2} \
               END{print "(" $5 ")" $3 " (" $4 ") " $2}')
    smallest_file() {
    printf "$by_size\n" |head -1
    }
    biggest_file() {
    printf "$by_size\n" |tail -1
    }
    SMALLEST_MESSAGE=$(printf '%s\n' "[Smallest:$(smallest_file)]")
    BIGGEST_MESSAGE=$(printf '%s\n' "[Biggest:$(biggest_file)]")
    SMALLBIG_MESSAGE=$(printf "$template" "${SMALLEST_MESSAGE}" "${BIGGEST_MESSAGE}")
}

## Is there a file newer than min_age?
[ "$MIN_AGE" -gt 0 ] && {
    newer_files_nb "${search}";
    [ "${NEWER_FILES_NB}" -gt 0 ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${NEWER_FILES_NB} files newer than ${MIN_AGE} minutes in ${SEARCH_PATH} ${tag}"${sep}"${NEWEST_MESSAGE}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

## Is there a file older than max_age?
[ "$MAX_AGE" -gt -1 ] && {
    older_files_nb "${search}"
    [ "${OLDER_FILES_NB}" -gt 0 ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${RETURN_MESSAGE}${OLDER_FILES_NB} files older than ${MAX_AGE} minutes in ${SEARCH_PATH} ${tag}"${sep}"${OLDEST_MESSAGE}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

## Is there too many files?
[ "$MAX_COUNT" -gt -1 ] && {
    [ "${NB_FILES}" -gt "${MAX_COUNT}" ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${RETURN_MESSAGE}More than ${MAX_COUNT} files found : ${NB_FILES} files in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

## Is there too few files?
[ "$MIN_COUNT" -gt 0 ] && {
    [ "${NB_FILES}" -lt "${MIN_COUNT}" ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${RETURN_MESSAGE}Less than ${MIN_COUNT} files found : ${NB_FILES} files in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

## Is there files which are too big?
[ "$MAX_SIZE" -gt -1 ] && {
    bigger_files_nb "${search}"
    [ "${BIGGER_FILES_NB}" -gt 0 ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${RETURN_MESSAGE}${BIGGER_FILES_NB} files over ${MAX_SIZE} kB in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"${sep}"${BIGGEST_MESSAGE}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

## Is there files which are too small?
[ "$MIN_SIZE" -gt 0 ] && {
    smaller_files_nb "${search}"
    [ "${SMALLER_FILES_NB}" -gt 0 ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${RETURN_MESSAGE}${SMALLER_FILES_NB} files under ${MIN_SIZE} kB in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"${sep}"${SMALLEST_MESSAGE}}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

# Measure disk usage
if [ "$MIN_USAGE" -gt 0 -o "$MAX_USAGE" -gt -1 ]
then
    disk_usage "$search"
    USAGE_MESSAGE="(${DISK_USAGE} kB)"
else
    DISK_USAGE=0
fi

## More perfdata
PERFDATA="${PERFDATA} nb_files_older=${OLDER_FILES_NB} disk_usage=${DISK_USAGE}KB;$MAX_USAGE"

## Is there too much space used?
[ "$MAX_USAGE" -gt -1 ] && {
    [ "$DISK_USAGE" -gt "$MAX_USAGE" ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${RETURN_MESSAGE}${SEARCH_PATH} uses more than $MAX_USAGE kB ${USAGE_MESSAGE}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

## Is there too few space used?
[ "$MIN_USAGE" -gt 0 ] && {
    [ "$DISK_USAGE" -lt "$MIN_USAGE" ] && {
        RETURN_MESSAGE="${ERROR_PREFIX}${RETURN_MESSAGE}${SEARCH_PATH} uses less than $MIN_USAGE kB ${USAGE_MESSAGE}"${sep}
        RETURN_CODE="${ERROR_CODE}"
    } }

## Return message empty => Return 0 (OK) and a gentle & convenient message
[ -z "${RETURN_MESSAGE}" ] && {
    RETURN_MESSAGE="${OK_PREFIX}${SEARCH_PATH} - ${NB_FILES} files ${tag} ${USAGE_MESSAGE}"
    [ $SEARCH_AGE  ] && { RETURN_MESSAGE="${RETURN_MESSAGE}${OLDNEW_MESSAGE}"; }
    [ $SEARCH_SIZE ] && { RETURN_MESSAGE="${RETURN_MESSAGE}${SMALLBIG_MESSAGE}"; }
    RETURN_CODE=0
}

printf "${RETURN_MESSAGE}|$PERFDATA\n"
exit "${RETURN_CODE}"
