#!/usr/bin/env sh

#~ set -x

# Default values

## General behaviour
VERBOSE=false
VERBOSITY=0
RETURN_CODE=3                # UNKNOWN : Status if anything goes wrong past this line.
ERROR_CODE=2                 # CRITICAL : Status on error (use option -W to set it to 1 (WARNING) instead)
MULTILINE=false              # Output on one line by defaut

## Search caracteristics
SEARCH_PATH="."              # If not provided, search current dir
SEARCH_TYPE='f'              # Search only regular files
SEARCH_AGE=false             # Do not search for oldest and newest files
SEARCH_SIZE=false            # Do not search for biggest and tiniest files
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


 -d/--dir        <path>   Directory to search files in (default: \$HOME)
 -r/--recursive           Search recursively (default: $RECURSIVE)
 -t/--file-type  <string> Type of file to search for (default: $SEARCH_TYPE)
                          It may be any combination of the following letters:
                            
                            f : regular file
                            d : directory
                            l : symbolic link
                            
                          ex: 'fd' to search for regular files and directories.
                          
                          [NB]: '.' and '..' are counted when searching for directories.
                          
                          To check if a directory is empty use: -tfdl -N2
                          
                                    -tfdl -N2
                                    
 -i/--include    <string> Search only for files with this name
 -x/--exclude    <string> Exclude files with this name

                           
 -a/--min-age    <int>    Minimum age of the most recent file in minutes (default: ${MIN_AGE})
 -A/--max-age    <int>    Maximum age of the oldest file in minutes (default: ${MAX_AGE})
 -n/--min-count  <int>    Minimum number of files (default: ${MIN_COUNT})
 -N/--max-count  <int>    Maximum number of files (default: ${MAX_COUNT})
 -s/--min-size   <int>    Minimum size of each file in kB (default: ${MIN_SIZE})
 -S/--max-size   <int>    Maximum size of each file in kB (default: ${MAX_SIZE})
 -u/--min-usage  <int>    Minimum disk usage in kB (default: ${MIN_USAGE})
 -U/--max-usage  <int>    Maximum disk usage in kB (default: ${MAX_USAGE}) 
 -W/--warn-only           Return 1 (WARNING) instead of 2 (CRITICAL)
                          on constraints violation.
 -M/--multiline           Add line returns in the output
                           
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
     (*)                set -- "${@}" "${arg}"
  esac
done;

## Parse command line options
while getopts "vWhMlLi:x:d:ra:A:n:N:s:S:u:U:t:" opt; do
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
            exit ${RETURN_CODE};
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
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -a expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MIN_AGE=${OPTARG};
            fi
            ;;
        (A)
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -A expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MAX_AGE=${OPTARG};
            fi
            ;;
        (n)
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -n expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MIN_COUNT=${OPTARG};
            fi
            ;;
        (N)
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -N expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MAX_COUNT=${OPTARG};
            fi
            ;;
        (s)
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -s expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MIN_SIZE=${OPTARG};
            fi
            ;;
        (S)
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -S expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MAX_SIZE=${OPTARG};
            fi
            ;;
        (u)
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -u expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MIN_USAGE=${OPTARG};
            fi
            ;;
        (U)
            if ! is_int ${OPTARG};
            then
                printf "\n%s\n" "Option -U expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MAX_USAGE=${OPTARG};
            fi
            ;;
        (t)
            SEARCH_TYPE="${OPTARG}";
            ;;
        (M)
            MULTILINE=true
            ;;
        (\?)
            printf "%s\n" "Unsupported option...";
            help_message;
            RETURN_CODE=3
            exit ${RETURN_CODE};
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
    if [ $(expr length $1) -gt 2 ]
    then
        FIND_NAME_CLAUSE=" -name "$1
    fi
    if [ $(expr length $1) -gt 2 -a $(expr length $2) -gt 2  ]
    then
        FIND_NAME_CLAUSE=${FIND_NAME_CLAUSE}" -a "
    fi    
    if [ $(expr length $2) -gt 2  ]
    then
        FIND_NAME_CLAUSE=${FIND_NAME_CLAUSE}"! -name  "$2
    fi    
}
find_name_clause "'"${SEARCH_NAME_INCLUDE}"'" "'"${SEARCH_NAME_EXCLUDE}"'"

# Do find
do_find() {
cat <<EOF
find $*
EOF
}

# Count number of files newer than min-age
newer_files_nb() {
    NEWER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE} -mmin -${MIN_AGE} |wc -l)
}

# Count number of files older than max-age
older_files_nb() {
    OLDER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE} -mmin +${MAX_AGE} |wc -l)
}

# Count number of files smaller than min-size
smaller_files_nb() {
    SMALLER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE} -size -${MIN_SIZE}k |wc -l)
}

# Count number of files bigger than max-size
bigger_files_nb() {
    BIGGER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE} -size +${MAX_SIZE}k |wc -l)
}

# Measure disk usage

disk_usage() {
    DISK_USAGE=$(du -sk ${SEARCH_PATH} |cut -f1)
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
if $RECURSIVE
then 
    tag="(R${SEARCH_TYPE}i:'${SEARCH_NAME_INCLUDE}'x:'${SEARCH_NAME_EXCLUDE}')"
    search="$SEARCH_PATH"
else 
    tag="(${SEARCH_TYPE}i:'${SEARCH_NAME_INCLUDE}'x:'${SEARCH_NAME_EXCLUDE}')"
    search="$SEARCH_PATH/* $SEARCH_PATH/.* -prune"
fi

# Multiline?
if $MULTILINE
then
    template='\n%s\n%s\n'
else
    template='%s %s\n'
fi

## Count files
NB_FILES=$(eval $(do_find ${search} ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE}) |wc -l)

# Search for oldest and newest files
if is_gnu_find && $SEARCH_AGE
then
    format="-printf '%Cs;%Cc;%p;%k kB;%Y\n'"
    firstlast=$(eval $(do_find $search ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE} ${format}) |sort -n |awk 'BEGIN{FS=";"} {if (NR==1) print "(" $5 ")" $3 " (" $4 ") " $2} END{print "(" $5 ")" $3 " (" $4 ") " $2}')
    oldest_file() {
    printf "$firstlast\n" |head -1
    }
    newest_file() {
    printf "$firstlast\n" |tail -1
    }
    OLDEST_MESSAGE=$(printf '%s\n' "[Oldest:$(oldest_file)]")
    NEWEST_MESSAGE=$(printf '%s\n' "[Newest:$(newest_file)]")
    OLDNEW_MESSAGE=$(printf "$template" "${OLDEST_MESSAGE}" "${NEWEST_MESSAGE}")
fi

# Search for smallest and biggest files
if is_gnu_find && $SEARCH_SIZE
then
    format="-printf '%s;%Cc;%p;%k kB;%Y\n'"
    firstlast=$(eval $(do_find $search ${FIND_TYPE_CLAUSE} ${FIND_NAME_CLAUSE} ${format}) |sort -n |awk 'BEGIN{FS=";"} {if (NR==1) print "(" $5 ")" $3 " (" $4 ") " $2} END{print "(" $5 ")" $3 " (" $4 ") " $2}')
    smallest_file() {
    printf "$firstlast\n" |head -1
    }
    biggest_file() {
    printf "$firstlast\n" |tail -1
    }
    SMALLEST_MESSAGE=$(printf '%s\n' "[Smallest:$(smallest_file)]")
    BIGGEST_MESSAGE=$(printf '%s\n' "[Biggest:$(biggest_file)]")
    SMALLBIG_MESSAGE=$(printf "$template" "${SMALLEST_MESSAGE}" "${BIGGEST_MESSAGE}")
fi

## Is there a file newer than min_age?
if [ $MIN_AGE -gt 0 ]
then
    newer_files_nb "${search}";
    if [ ${NEWER_FILES_NB} -gt 0 ]
    then
        RETURN_MESSAGE="${NEWER_FILES_NB} files newer than ${MIN_AGE} minutes in ${SEARCH_PATH}${tag}${RETURN_MESSAGE_SEP}${NEWEST_MESSAGE}"
        RETURN_MESSAGE="${RETURN_MESSAGE}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## Is there a file older than max_age?
if [ $MAX_AGE -gt -1 ]
then
    older_files_nb "${search}"
    if [ ${OLDER_FILES_NB} -gt 0 ]
    then
        RETURN_MESSAGE="${OLDER_FILES_NB} files older than ${MAX_AGE} minutes in ${SEARCH_PATH}${tag}${RETURN_MESSAGE_SEP}${OLDEST_MESSAGE}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## Is there too many files?
if [ $MAX_COUNT -gt -1 ]
then
    if [ ${NB_FILES} -gt ${MAX_COUNT} ]
    then
        RETURN_MESSAGE="More than ${MAX_COUNT} files found : ${NB_FILES} files in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## Is there too few files?
if [ $MIN_COUNT -gt 0 ]
then
    if [ ${NB_FILES} -lt ${MIN_COUNT} ]
    then
        RETURN_MESSAGE="Less than ${MIN_COUNT} files found : ${NB_FILES} files in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## Is there files which are too big?
if [ $MAX_SIZE -gt -1 ]
then
    bigger_files_nb "${search}"
    if [ ${BIGGER_FILES_NB} -gt 0 ]
    then
        RETURN_MESSAGE="${BIGGER_FILES_NB} files over ${MAX_SIZE} kB in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag} ${BIGGEST_MESSAGE}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## Is there files which are too small?
if [ $MIN_SIZE -gt 0 ]
then
    smaller_files_nb "${search}"
    if [ ${SMALLER_FILES_NB} -gt 0 ]
    then
        RETURN_MESSAGE="${SMALLER_FILES_NB} files under ${MIN_SIZE} kB in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag} ${SMALLEST_MESSAGE}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

# Measure disk usage
disk_usage

## Is there too much space used?
if [ $MAX_USAGE -gt -1 ]
then
    if [ $DISK_USAGE -gt $MAX_USAGE ]
    then
        RETURN_MESSAGE="${SEARCH_PATH} uses more than $MAX_USAGE kB (${DISK_USAGE} kB)"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}    
    fi    
fi

## Is there too few space used?
if [ $MIN_USAGE -gt 0 ]
then
    if [ $DISK_USAGE -lt $MIN_USAGE ]
    then
        RETURN_MESSAGE="${SEARCH_PATH} uses less than $MIN_USAGE kB (${DISK_USAGE} kB)"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}    
    fi    
fi

## All tests passed successfully!
## Return 0 (OK) and a gentle & convenient message
if [ $NB_FILES -gt 0 ]
then
    RETURN_MESSAGE="${SEARCH_PATH} - ${NB_FILES} files ${tag} (${DISK_USAGE} kB) ${OLDNEW_MESSAGE} ${SMALLBIG_MESSAGE}"
else
    RETURN_MESSAGE="${SEARCH_PATH} - ${NB_FILES} files ${tag}"
fi    
RETURN_CODE=0
printf "%s\n" "${RETURN_MESSAGE}"
exit ${RETURN_CODE}
