#!/usr/bin/env sh

is_gnu_find() {
    if [ $(find --version 2>/dev/null |grep -cw GNU) -gt 0 ]
    then
        true
    else
        false
    fi    
}

toto=$(/bin/true)

[ is_gnu_find -a "$toto" ] && echo "Yes" || echo "No"

