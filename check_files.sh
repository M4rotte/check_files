#!/usr/bin/env sh

set +x

# Default values

## General behaviour
VERBOSE=false
VERBOSITY=0
RETURN_CODE=3                # UNKNOWN : Status if anything goes wrong past this line.
ERROR_CODE=2                 # CRITICAL : Status on error (use option -W to set it to 1 (WARNING) instead)
SEARCH_PATH=$HOME            # If not provided, search there
SEARCH_TYPE='f'              # Search this kind of file
FIND_TYPE_CLAUSE=""          # Will store the type options for the find command
RECURSIVE=false              # Do not search in sub directories 
SEARCH_AGE=false             # Do not search for oldest and newest files
SEARCH_SIZE=false            # Do not search for biggest and tiniest files
RETURN_MESSAGE=""

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

# Help message

help_message() {
cat <<EOF

$(basename "$0")

Check some properties on files in a given directory on POSIX systems.

Returns OK, only if all the constraints are met.

Usage: $(basename "$0") [-vhrWlL] [-a min-age] [-A max-age] [-n min-count] [-N max-count]
                        [-s min-size] [-S max-size] [-t filetype]


 -d/--dir        <path>   Directory to search files in (default: \$HOME)
 -r/--recursive           Search recursively (default: $RECURSIVE)
 -t/--file-type  <string> Type of file to search for (default: $SEARCH_TYPE)
                          It may be any combination of the following letters:
                            
                            f : regular file
                            d : directory
                            l : symbolic link
                            
                          ex: 'fd' to search for files and directories.  
                           
 -a/--min-age    <int>    Minimum age of the most recent file in minutes (default: ${MIN_AGE})
 -A/--max-age    <int>    Maximum age of the oldest file in minutes (default: ${MAX_AGE})
 -n/--min-count  <int>    Minimum number of files (default: ${MIN_COUNT})
 -N/--max-count  <int>    Maximum number of files (default: ${MAX_COUNT})
 -s/--min-size   <int>    Minimum size of each file in kB (default: ${MIN_SIZE})
 -S/--max-size   <int>    Maximum size of each file in kB (default: ${MAX_SIZE}) 
 -W/--warn-only           Return 1 (WARNING) instead of 2 (CRITICAL)
                          on constraints violation.
                           
 -h/--help                Show this help
 -v/--verbose             Verbose mode
 
 The following options have no effect on systems without GNU find.
 
 -l/--search-age          Search for oldest and newest files. (default: $SEARCH_AGE)
 -L/--search-size         Search for biggest and smallest files. (default: $SEARCH_SIZE)
                          Thoses searches can be particulary long if used
                          in conjonction with -r (recursive).

EOF
};

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
     ("--recursive")    set -- "${@}" "-r" ;;
     ("--file-type")    set -- "${@}" "-t" ;;
     ("--warn-only")    set -- "${@}" "-W" ;;
     ("--search-age")   set -- "${@}" "-l" ;;
     ("--search-size")  set -- "${@}" "-L" ;;
     (*)                set -- "${@}" "${arg}"
  esac
done;

## Parse command line options
while getopts "vWhd:ra:A:n:N:s:S:t:lL" opt; do
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
        (t)
            SEARCH_TYPE="${OPTARG}";
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
        (fd|df)                   SEARCH_TYPE="fd"; FIND_TYPE_CLAUSE=" ( -type f -o -type d ) " ;;
        (fl|lf)                   SEARCH_TYPE="fl"; FIND_TYPE_CLAUSE=" ( -type f -o -type l ) " ;;
        (ld|dl)                   SEARCH_TYPE="dl"; FIND_TYPE_CLAUSE=" ( -type l -o -type d ) " ;;
        (fld|fdl|ldf|lfd|dfl|dlf)
            SEARCH_TYPE="fdl"
            FIND_TYPE_CLAUSE=" ( -type l -o -type d -o -type f ) "
            ;;
        (*)
            (>&2 echo "Search type '${SEARCH_TYPE}' invalid, switching to 'f'.")                       
            SEARCH_TYPE="f"; FIND_TYPE_CLAUSE=" -type f "
        ;;
    esac    
}
find_type_clause "${SEARCH_TYPE}"

# Count files
nb_files() {
    NB_FILES=$(find $1 ${FIND_TYPE_CLAUSE} |wc -l)
    typeset -i NB_FILES  2>/dev/null
}

# Count number of files newer than min-age
newer_files_nb() {
    NEWER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} -mmin -${MIN_AGE} |wc -l)
    typeset -i NEWER_FILES_NB 2>/dev/null
}

# Count number of files older than max-age
older_files_nb() {
    OLDER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} -mmin +${MAX_AGE} |wc -l)
    typeset -i OLDER_FILES_NB 2>/dev/null
}

# Count number of files smaller than min-size
smaller_files_nb() {
    SMALLER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} -size -${MIN_SIZE}k |wc -l)
    typeset -i SMALLER_FILES_NB 2>/dev/null
}

# Count number of files bigger than max-size
bigger_files_nb() {
    BIGGER_FILES_NB=$(find $1 ${FIND_TYPE_CLAUSE} -size +${MAX_SIZE}k |wc -l)
    typeset -i BIGGER_FILES_NB 2>/dev/null
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
    tag="(R${SEARCH_TYPE})"
    search="$SEARCH_PATH"
else 
    tag="(${SEARCH_TYPE})"
    search="$SEARCH_PATH/* $SEARCH_PATH/.* -prune"
fi

# Search for oldest and newest files
if is_gnu_find && $SEARCH_AGE
then
    firstlast=$(find $search $FIND_TYPE_CLAUSE -printf "%Cs;%Cc;%p;%k kB;%Y\n" |sort -n |awk 'BEGIN{FS=";"} {if (NR==1) print "(" $5 ")" $3 " (" $4 ") " $2} END{print "(" $5 ")" $3 " (" $4 ") " $2}')
    oldest_file() {
    printf "$firstlast\n" |head -1
    }
    newest_file() {
    printf "$firstlast\n" |tail -1
    }
    OLDEST_MESSAGE="[Oldest:$(oldest_file)]"
    NEWEST_MESSAGE="[Newest:$(newest_file)]"
    OLDNEW_MESSAGE="${OLDEST_MESSAGE}${NEWEST_MESSAGE}"
fi

# Search for smallest and biggest files
if is_gnu_find && $SEARCH_SIZE
then
    firstlast=$(find $search $FIND_TYPE_CLAUSE -printf "%s;%Cc;%p;%k kB;%Y\n" |sort -n |awk 'BEGIN{FS=";"} {if (NR==1) print "(" $5 ")" $3 " (" $4 ") " $2} END{print "(" $5 ")" $3 " (" $4 ") " $2}')
    smallest_file() {
    printf "$firstlast\n" |head -1
    }
    biggest_file() {
    printf "$firstlast\n" |tail -1
    }
    SMALLEST_MESSAGE="[Smallest:$(smallest_file)]"
    BIGGEST_MESSAGE="[Biggest:$(biggest_file)]"
    SMALLBIG_MESSAGE="${SMALLEST_MESSAGE}${BIGGEST_MESSAGE}"
fi

## Is there a file newer than min_age?
if [ $MIN_AGE -gt 0 ]
then
    newer_files_nb "${search}";
    if [ ${NEWER_FILES_NB} -gt 0 ]
    then
        RETURN_MESSAGE="${NEWER_FILES_NB} files newer than ${MIN_AGE} minutes in ${SEARCH_PATH}${tag} ${NEWEST_MESSAGE}"
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
        RETURN_MESSAGE="${OLDER_FILES_NB} files older than ${MAX_AGE} minutes in ${SEARCH_PATH}${tag} ${OLDEST_MESSAGE}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## Count files
nb_files "${search}"

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
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"
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
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH} ${tag}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## All tests passed successfully!
## Return 0 (OK) and a gentle & convenient message
if [ $NB_FILES -gt 0 ]
then
    RETURN_MESSAGE="${SEARCH_PATH} - ${NB_FILES} files ${tag} ${OLDNEW_MESSAGE} ${SMALLBIG_MESSAGE}"
else
    RETURN_MESSAGE="${SEARCH_PATH} - ${NB_FILES} files ${tag}"
fi    
RETURN_CODE=0
printf "%s\n" "${RETURN_MESSAGE}"
exit ${RETURN_CODE}
