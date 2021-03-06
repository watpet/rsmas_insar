#!/bin/bash
#set -x

# insert ' into intersectsWith string that is chopped off by bash
copy=( "$@" )
for i in "${!copy[@]}"; do
    if [[ ${copy[$i]} == *intersectsWith=* ]]; then
        tmp1=${copy[$i]:0:17}
        tmp2=${copy[$i]:17:${#copy[$i]}}
        copy[$i]="$tmp1'$tmp2'"
    elif [[ ${copy[$i]} == --parallel* ]]; then
        parallel=$(echo ${copy[$i]} | cut -d= -f2)
    fi
    echo element: $i ${copy[$i]}
done

echo "$(date +"%Y%m%d:%H-%m") * `basename "$0"` "${copy[@]}" " >> log

argv=( "$@" )


if  [[ -z "$parallel" ]] ; then 
   parallel=5 
fi

timeout=400

echo "parallel=${parallel}"
user=`grep asfuser $RSMASINSAR_HOME/3rdparty/SSARA/password_config.py | sed 's/\"//g''' | cut -d '=' -f 2`
passwd=`grep asfpass $RSMASINSAR_HOME/3rdparty/SSARA/password_config.py | sed 's/\"//g''' | cut -d '=' -f 2`

echo "Running ... ssara_federated_query.py ${argv[@]:0:$#-1} > ssara_listing.txt"
ssara_federated_query.py "${argv[@]:0:$#-1}" > ssara_listing.txt

regex="https:\/\/datapool\.asf\.alaska\.edu\/[a-zA-Z\/0-9\_]+\.zip"

urls=$(grep -oP $regex ssara_listing.txt)

# putting into background creates error code 123 
#echo $urls | xargs -n 1 -P $parallel wget -nc --user $user --password $passwd 2>/dev/null
echo $urls | xargs -n 1 -P $parallel timeout $timeout wget --continue --user $user --password $passwd 
exit_code=$?
echo "Exit code from wget commands: $exit_code"

runs=1
while [ $exit_code -eq 123 -o $exit_code -eq 127 ] && [ $runs -lt 3 ]; do
    echo "Something went wrong. Exit code was ${exit_code}. Trying again with ${t} second timeout."
    echo "$(date +"%Y%m%d:%H-%m") * Something went wrong. Exit code was ${exit_code}. Trying again with ${t} second timeout" >> log
    echo $urls | xargs -n 1 -P $parallel timeout $timeout wget --continue --user $user --password $passwd
    exit_code=$?
    runs=$((runs+1))
    sleep 60
done

if [[ $exit_code -ge 3 ]]; then
    exit 3
fi

exit 0

