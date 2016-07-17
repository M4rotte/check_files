#!/usr/bin/env sh

set +x

# Default values

## General behaviour
VERBOSE=false
VERBOSITY=0
RETURN_CODE=3      # UNKNOWN : Default status if anything goes wrong past this line.
ERROR_CODE=2       # CRITICAL : Default status on error (use option -W to set it to 1 (WARNING) instead)
RECURSIVE=false    # Do not search in sub directories by default
SEARCH_PATH=$HOME  # If not provided, search there...
RETURN_MESSAGE=""

## Age constraints
MIN_AGE=0
NEWER_FILES_NB=0

MAX_AGE=-1
OLDER_FILES_NB=0

## Count constraints
MIN_COUNT=0
MAX_COUNT=-1

# Help message

help_message() {
cat <<EOF

$(basename "$0")

Check some properties on files in a given directory on POSIX systems.

Returns OK, only if all the constraints are met.

Usage: $(basename "$0") [-vhrW] [-a min-age] [-A max-age] [-n min-count] [-N max-count]


 -d/--dir         <path>   Directory to search files in (default: \$HOME)
 -r/--recursive            Search recursively (default: false) 
 -a/--min-age     <int>    Minimum age of the most recent file in minutes (default: ${MIN_AGE})
 -A/--max-age     <int>    Maximum age of the oldest file in minutes (default: ${MAX_AGE})
 -n/--min-count   <int>    Minimum number of files (default: ${MIN_COUNT})
 -N/--max-count   <int>    Maximum number of files (default: ${MAX_COUNT})
 -W/--warn-only            Return 1 (WARNING) instead of 2 (CRITICAL) on constraints violation
 -h/--help                 Show this help
 -v/--verbose              Verbose mode

EOF
};

# Check if one provides "abc" as a numeric value...
is_int() {
    case "$1" in
        (*[!0-9]*|'')
            false;
            ;;
        (*) true
    esac
}

# Count regular files
nb_files() {
if ${RECURSIVE}
then
    NB_FILES="$(find "$1" -type f |wc -l)"
else    
    NB_FILES="$(find "$1"/* "$1"/.* -prune -type f |wc -l)"
fi
typeset -i NB_FILES  2>/dev/null
}

# Count number of files newer than min-age
newer_files_nb() {
if ${RECURSIVE};
then
    NEWER_FILES_NB=$(find "$1" -type f -mmin -${MIN_AGE} |wc -l)
else
    NEWER_FILES_NB=$(find "$1"/* "$1"/.* -prune -type f -mmin -${MIN_AGE} |wc -l)
fi
typeset -i NEWER_FILES_NB 2>/dev/null
}

# Count number of files older than max-age
older_files_nb() {
if ${RECURSIVE};
then
    OLDER_FILES_NB=$(find "$1" -type f -mmin +${MAX_AGE} |wc -l)
else
    OLDER_FILES_NB=$(find "$1"/* "$1/".* -prune -type f -mmin +${MAX_AGE} |wc -l)
fi
typeset -i OLDER_FILES_NB 2>/dev/null
}

# Arguments management #

## KISS way to handle long options
for arg in "${@}"; do
  shift
  case "${arg}" in
     ("--verbose")   set -- "${@}" "-v" ;;
     ("--help")      set -- "${@}" "-h" ;;
     ("--dir")       set -- "${@}" "-d" ;;
     ("--min-age")   set -- "${@}" "-a" ;;
     ("--max-age")   set -- "${@}" "-A" ;;
     ("--min-count") set -- "${@}" "-n" ;;
     ("--max-count") set -- "${@}" "-N" ;;
     ("--recursive") set -- "${@}" "-r" ;;
     ("--warn-only") set -- "${@}" "-W" ;;     
     (*)             set -- "${@}" "${arg}"
  esac
done;

## Parse command line options
while getopts "vWhd:ra:A:n:N:" opt; do
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
                printf "\n%s\N" "Option -N expects a positive integer number as argument."
                RETURN_CODE=3;
                exit ${RETURN_CODE};
            else
                MAX_COUNT=${OPTARG};
            fi
            ;;
        (\?)
            printf "%s\n" "Unsupported option...";
            help_message;
            RETURN_CODE=3
            exit ${RETURN_CODE};
            ;;
    esac
done;

# Main script #

## Recursive?
if $RECURSIVE
then 
    tag='(R)'
else 
    tag=''
fi

if [ $MIN_AGE -gt 0 ]
then
    ## Is there a file newer than min_age?
    newer_files_nb "${SEARCH_PATH}";
    if [ ${NEWER_FILES_NB} -gt 0 ]
    then
        RETURN_MESSAGE="${NEWER_FILES_NB} files newer than ${MIN_AGE} minutes in ${SEARCH_PATH}${tag}"
        RETURN_MESSAGE="${RETURN_MESSAGE}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

if [ $MAX_AGE -gt -1 ]
then
    ## Is there a file older than max_age?
    older_files_nb "${SEARCH_PATH}"
    if [ ${OLDER_FILES_NB} -gt 0 ]
    then
        RETURN_MESSAGE="${OLDER_FILES_NB} files older than ${MAX_AGE} minutes in ${SEARCH_PATH}${tag}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## Count regular files
nb_files "${SEARCH_PATH}"


if [ $MAX_COUNT -gt -1 ]
then
    ## Is there too many files?
    if [ ${NB_FILES} -gt ${MAX_COUNT} ]
    then
        RETURN_MESSAGE="More than ${MAX_COUNT} files found : ${NB_FILES} files in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH}${tag}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

if [ $MIN_COUNT -gt 0 ]
then
    ## Is there not enough files?
    if [ ${NB_FILES} -lt ${MIN_COUNT} ]
    then
        RETURN_MESSAGE="Less than ${MIN_COUNT} files found : ${NB_FILES} files in "
        RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH}${tag}"
        RETURN_CODE=${ERROR_CODE}
        printf "%s\n" "${RETURN_MESSAGE}"
        exit ${RETURN_CODE}
    fi
fi

## All tests passed successfully!
## Return 0 (OK) and a gentle & convenient message
if [ ${NB_FILES} -gt 0 ]
then
    RETURN_MESSAGE="${SEARCH_PATH}${tag} - ${NB_FILES} files"
else
    RETURN_MESSAGE="${SEARCH_PATH}${tag} - No regular file"
fi    
RETURN_CODE=0
printf "%s\n" "${RETURN_MESSAGE}"
exit ${RETURN_CODE}
