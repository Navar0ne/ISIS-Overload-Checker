#!/bin/bash
#
# Check ISIS Overload Timeout, then send a report via email.
#
# script=$0

mkdir tmp > /dev/null 2>&1 #Creates necessary directories
rm tmp/* > /dev/null 2>&1
unset TEST

while getopts "t" arg; do
    case "$arg" in
        t) TEST="test"
    esac
done

for router in `cat /home/neteam/code/etc/allrouters.txt`; do #Iterates through the routers in the specified file
    overload_num=$(ssh -q -o StrictHostKeyChecking=no srv_ne_scripts@${router} "show configuration protocols isis | match overload") # SSHes into each and inouts the command shown
    returnval="$?"

    if [[ $returnval == "0" ]];
    then
        if [[ -z "$overload_num" ]] ;
        then
            echo -e "$router: ISIS Overload not enabled" | tee -a tmp/output
        else
            if [[ $overload_num == "overload timeout 300;" ]]; 
            then
                echo -e "$router: ISIS Overload Timeout at: 300 ticks!" | tee -a tmp/output
            elif [[ $overload_num == "overload;" ]]; 
            then
                echo -e "$router: WARNING! ISIS Overload Timeout at: 0 ticks!" | tee -a tmp/output
            else
                echo "$router: ISIS Overload Timeout at: $overload_num ticks!" | tee -a tmp/output # Reads the output of the command, and writes the information into a file
            fi
        fi
    else
        echo "$router : WARNING CONNECTION FAILED!" | tee -a tmp/output
    fi
done

if [ "$TEST" ]; then
    exit 0
elif [ -f tmp/output ]; then # Writes an email in a local file
        echo "....Preparing email..."
        CWD=$(pwd)
        HOSTNAME=$(hostname)
        DOMAINNAME=$(dnsdomainname)
        echo "To: noc@geant.org" >> tmp/email
        echo "Subject: ISIS Overload Timeout Report" >> tmp/email
	    echo "" >> tmp/email
        if [ -f tmp/output ]; then
            echo "Following ISIS Overload Timeouts are in place:" >> tmp/email
            echo -e "\n" >> tmp/email
            cat tmp/output >> tmp/email
            echo -e "\n" >> tmp/email
        fi

        echo "" >> tmp/email
        echo "--------------------------------------------" >> tmp/email
	    echo "Ref: https://wiki.geant.org/display/GOC/ISIS+Overload+Checking+Script" >> tmp/email
        echo "--------------------------------------------" >> tmp/email
        echo "This email was generated via ${CWD}/${0} running on ${HOSTNAME}" >> tmp/email
        echo "For support issues with this script, contact oc@geant.org / OC team." >> tmp/email

        cat tmp/email | msmtp --host=mail.geant.net --port=25 -t -f neteam@neteam-server01.geant.org& # Sends email to GOC using internal SMTP server
else
    exit 0
fi

