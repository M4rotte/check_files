#!/usr/bin/env sh
##!/bin/bash --posix # dash has no typeset...

set +x

# Default values

## General behaviour
VERBOSE=false
VERBOSITY=0
RETURN_CODE=3      # UNKNOWN : Default status in anything goes wrong past this line.
ERROR_CODE=2       # CRITICAL : Default status on error (use option -W to set it to 1 (WARNING) instead)
RECURSIVE=false    # Do not search in sub directories by default
SEARCH_PATH=$HOME  # If not provided, search there...
RETURN_MESSAGE=""

## Age constraints
MIN_AGE=0          # By default, catch any file...
NEWER_FILES_NB=0
NEWEST_FILE_NAME=""
NEWEST_FILE_DATE=""

MAX_AGE=10512000   # ~20 years, TODO: permit -1 for no max
OLDER_FILES_NB=0
OLDEST_FILE_NAME=""
OLDEST_FILE_DATE=""

## Count constraints
MIN_COUNT=0
MAX_COUNT=65535    # Totally arbitrary

# Help message

help_message() {
cat <<EOF

$(basename "$0")

Check some properties on files in a given directory on POSIX systems.

Returns OK, only if all the constraints are met.

Usage: $(basename "$0") [-h]


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
    NB_FILES="$(find "$SEARCH_PATH" -type f |wc -l)"
else    
    NB_FILES="$(find "$SEARCH_PATH"/* "$SEARCH_PATH"/.* -prune -type f |wc -l)"
fi
typeset -i NB_FILES  # not POSIX, unsupported by dash    
}

# Find the newest file
newest_file() {
if ${RECURSIVE};
then
    NEWEST_FILE="$(find $1 -type f |xargs ls -aot | head -n 1)"
    NEWER_FILES_NB="$(find $1 -type f -mmin -${MIN_AGE} |wc -l)"
else
    NEWEST_FILE="$(find $1/* $1/.* -prune -type f |xargs ls -aot | head -n 1)"
    NEWER_FILES_NB="$(find $1/* $1/.* -prune -type f -mmin -${MIN_AGE} |wc -l)"
fi
NEWEST_FILE_DATE="$(echo "$NEWEST_FILE" |awk '{print $5 " " $6 " " $7}')"
NEWEST_FILE_NAME="$(echo "$NEWEST_FILE" |awk '{print $8}')"
}

# Find the oldest file
oldest_file() {
if ${RECURSIVE};
then
    OLDEST_FILE="$(find $1 -type f |xargs ls -aort | head -n 1)"
    OLDER_FILES_NB="$(find $1 -type f -mmin +${MAX_AGE} |wc -l)"
else
    OLDEST_FILE="$(find $1/* $1/.* -prune -type f |xargs ls -aort | head -n 1)"
    OLDER_FILES_NB="$(find $1/* $1/.* -prune -type f -mmin +${MAX_AGE} |wc -l)"
fi
OLDEST_FILE_DATE="$(echo "$OLDEST_FILE" |awk '{print $5 " " $6 " " $7}')"
OLDEST_FILE_NAME="$(echo "$OLDEST_FILE" |awk '{print $8}')"
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
                printf "\n%s\N" "Option -A expects a positive integer number as argument."
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

## Is there a file newer than min_age?
newest_file "${SEARCH_PATH}";
if [ ${NEWER_FILES_NB} -gt 0 ]
then
    typeset -i NEWER_FILES_NB; # not POSIX, unsupported by dash
    RETURN_MESSAGE="${NEWER_FILES_NB} files newer than ${MIN_AGE} minutes in "
    RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH}${tag} - ${NEWEST_FILE_NAME} (${NEWEST_FILE_DATE})"
    RETURN_CODE=${ERROR_CODE}
    printf "%s\n" "${RETURN_MESSAGE}"
    exit ${RETURN_CODE}
fi

## Is there a file older than max_age?
oldest_file "${SEARCH_PATH}"
if [ ${OLDER_FILES_NB} -gt 0 ]
then
    typeset -i OLDER_FILES_NB # not POSIX, unsupported by dash
    RETURN_MESSAGE="${OLDER_FILES_NB} files older than ${MAX_AGE} minutes in "
    RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH}${tag} - ${OLDEST_FILE_NAME} (${OLDEST_FILE_DATE})"
    RETURN_CODE=${ERROR_CODE}
    printf "%s\n" "${RETURN_MESSAGE}"
    exit ${RETURN_CODE}
fi

## Count regular files
nb_files

## Is there too many files?
if [ ${NB_FILES} -gt ${MAX_COUNT} ]
then
    RETURN_MESSAGE="More than ${MAX_COUNT} files found : ${NB_FILES} files in "
    RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH}${tag}"
    RETURN_CODE=${ERROR_CODE}
    printf "%s\n" "${RETURN_MESSAGE}"
    exit ${RETURN_CODE}
fi

## Is there not enough files?
if [ ${NB_FILES} -lt ${MIN_COUNT} ]
then
    RETURN_MESSAGE="Less than ${MIN_COUNT} files found : ${NB_FILES} files in "
    RETURN_MESSAGE="${RETURN_MESSAGE}${SEARCH_PATH}${tag}"
    RETURN_CODE=${ERROR_CODE}
    printf "%s\n" "${RETURN_MESSAGE}"
    exit ${RETURN_CODE}
fi

## All tests passed successfully!
## Return 0 (OK) and a gentle & convenient message
if [ ${NB_FILES} -gt 0 ]
then
    RETURN_MESSAGE="${SEARCH_PATH}${tag} - ${OLDEST_FILE_NAME} (${OLDEST_FILE_DATE}) > ${NEWEST_FILE_NAME} (${NEWEST_FILE_DATE}) - ${NB_FILES} files"
else
    RETURN_MESSAGE="${SEARCH_PATH}${tag} - No regular file"
fi    
RETURN_CODE=0
printf "%s\n" "${RETURN_MESSAGE}"
exit ${RETURN_CODE}
