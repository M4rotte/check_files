#!/bin/bash --posix
#~ #!/usr/bin/env sh

set +x

## Default values

VERBOSE=false
VERBOSITY=0
RETURN_CODE=3 # UNKNOWN
RETURN_MESSAGE=""

SEARCH_PATH="/tmp"
RECURSIVE=false
ERROR_CODE=2 # CRITICAL

MIN_AGE=0
NEWER_FILES_NB=0
NEWEST_FILE_NAME=""
NEWEST_FILE_DATE=""

MAX_AGE=10512000 # ~20 years
OLDER_FILES_NB=0
OLDEST_FILE_NAME=""
OLDEST_FILE_DATE=""

MIN_FILES=0
MAX_FILES=65535 # Totally arbitrary
## Help message

help_message() {
cat <<EOF

$(basename "$0")

Check some properties on files in a given directory on POSIX systems.

Usage: $(basename "$0") [-h]

 -d/--dir         <path>   Directory to search files in (default: ${SEARCH_PATH})
 -r/--recursive            Search recursively (default: false) 
 -a/--min-age     <int>    Minimum age of the most recent file in minutes (default: ${MIN_AGE})
 -A/--max-age     <int>    Maximum age of the oldest file in minutes (default: ${MAX_AGE})
 -n/--min-number  <int>    Minimum number of files (default: ${MIN_COUNT})
 -W/--warn_only            Return 1 (WARNING) instead of 2 (CRITICAL) on constraints violation
 -h/--help                 Show this help
 -v/--verbose              Verbose mode

EOF
};

is_int() {
    case "$1" in
        (*[!0-9]*|'')
            false;
            ;;
        (*) true
    esac
}

newest_file() {

if ${RECURSIVE};
then
    NEWEST_FILE="$(find $1 -type f |xargs ls -alt | head -n 1)"
    NEWER_FILES_NB="$(find $1 -type f -mmin -${MIN_AGE} |wc -l)"
else
    NEWEST_FILE="$(find $1/* -prune -type f |xargs ls -alt | head -n 1)"
    NEWER_FILES_NB="$(find $1/* -prune -type f -mmin -${MIN_AGE} |wc -l)"
fi
NEWEST_FILE_DATE="$(echo "$NEWEST_FILE" |awk '{print $6 " " $7 " " $8}')"
NEWEST_FILE_NAME="$(echo "$NEWEST_FILE" |awk '{print $9}')"
}

oldest_file() {

if ${RECURSIVE};
then
    OLDEST_FILE="$(find $1 -type f |xargs ls -alrt | head -n 1)"
    OLDER_FILES_NB="$(find $1 -type f -mmin +${MAX_AGE} |wc -l)"
else
    OLDEST_FILE="$(find $1/* -prune -type f |xargs ls -alrt | head -n 1)"
    OLDER_FILES_NB="$(find $1/* -prune -type f -mmin +${MAX_AGE} |wc -l)"
fi
OLDEST_FILE_DATE="$(echo "$OLDEST_FILE" |awk '{print $6 " " $7 " " $8}')"
OLDEST_FILE_NAME="$(echo "$OLDEST_FILE" |awk '{print $9}')"
}



## Arguments management ##

for arg in "${@}"; do
  shift
  case "${arg}" in
     ("--verbose")   set -- "${@}" "-v" ;;
     ("--help")      set -- "${@}" "-h" ;;
     ("--dir")       set -- "${@}" "-d" ;;
     ("--min-age")   set -- "${@}" "-a" ;;
     ("--max-age")   set -- "${@}" "-A" ;;
     ("--recursive") set -- "${@}" "-r" ;;
     (*)             set -- "${@}" "${arg}"
  esac
done;

while getopts "vWhd:ra:A:" opt; do
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
        (\?)
            printf "%s\n" "Unsupported option...";
            help_message;
            RETURN_CODE=3
            exit ${RETURN_CODE};
            ;;
    esac
done;

## Main script ##

## Is there a file newer than min_age?
newest_file "${SEARCH_PATH}";
if [ ${NEWER_FILES_NB} -gt 0 ];
then
    typeset -i NEWER_FILES_NB; # not POSIX, unsupported by dash
    RETURN_MESSAGE="${NEWER_FILES_NB} files newer than ${MIN_AGE} minutes in ";
    RETURN_MESSAGE="${RETURN_MESSAGE}'${SEARCH_PATH}' Newest:${NEWEST_FILE_NAME} (${NEWEST_FILE_DATE})";
    RETURN_CODE=${ERROR_CODE};
    printf "%s\n" "${RETURN_MESSAGE}";
    exit ${RETURN_CODE};
fi

## Is there a file older than max_age?
oldest_file "${SEARCH_PATH}";
if [ ${OLDER_FILES_NB} -gt 0 ];
then
    typeset -i OLDER_FILES_NB; # not POSIX, unsupported by dash
    RETURN_MESSAGE="${OLDER_FILES_NB} files older than ${MAX_AGE} minutes in ";
    RETURN_MESSAGE="${RETURN_MESSAGE}'${SEARCH_PATH}' Oldest:${OLDEST_FILE_NAME} (${OLDEST_FILE_DATE})";
    RETURN_CODE=${ERROR_CODE};
    printf "%s\n" "${RETURN_MESSAGE}";
    exit ${RETURN_CODE};
fi

## All tests passed successfully!
## Return 0 (OK) and a convenient message

if $RECURSIVE; then tag='(R)'; else tag=''; fi;
RETURN_MESSAGE="${SEARCH_PATH}${tag} - Newest:${NEWEST_FILE_NAME} (${NEWEST_FILE_DATE}) Oldest:${OLDEST_FILE_NAME} (${OLDEST_FILE_DATE})";
RETURN_CODE=0
printf "%s\n" "${RETURN_MESSAGE}";
exit ${RETURN_CODE};
