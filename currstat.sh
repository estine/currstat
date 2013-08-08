#!/usr/bin/sh

# Eli Stine
# CS241 - Sys. Prog.
# 11-13-12
#
# currstat.sh
# Displays the current status of a user, including info. about processes and server usage heuristics
#
# usage: ./currstat.sh <username> [-afgiptw]
#
# Functionality:
# 1) Full name of user, position (student, teacher, alumni, sysadmin, etc.)
     # 1a) If they have a website named after them (-w flag)
# 2) Last x commands they made (default is 3) (increases to 10 with -p flag)
     # 2a) Process they have with greatest virtual memory usage and process they have with greatest number of pages (-g flag)
     # 2b) Process tree for user (-t flag)
# 3) Number of connections on their IP address
# 4) Current session length
     # 4a) How long they've been idle, if they're idle (-i flag)
# Bonus: -a flag sets all flags on

#################################################################################################

### Argument Parsing

# For each argument user gives
# If they have no arguments exit with error
if [ "$#" -eq  0 ]; then
    echo "usage: currstat.sh [-afgiptw] <username>"
    exit 1 # exit shell script with error 
else # There is at least one argument
# Set up vars for flags
g=0 ; i=0 ; p=0 ; t=0 ; w=0

for var in "$@" # For each command line argument
    do
        firstChar=`echo $var | cut -c 1` # get first character
        if [ $firstChar != "-" ]; then # If it's not a flag (assume username)
            # Check if it's a username
	    userCheck=`id $var` # Will return error if username doesn't exist
	    # If it gets to here then an error hasn't occured
	    if [ ! -n "$userCheck" ]; then # if user is empty/some other issue
		exit 1
	    else
		user=$var # Set local variable to username
	    fi
	else # Assume it's a flag
            flag=`echo $var | cut -c 2` # Get the flag itself
	    if [ ! -n "$flag" ]; then # Empty flag
		echo "usage: currstat.sh [-agiptw] <username>"
		exit 1
	    fi

	    # Cases for flags
	    case $flag in
		a) g=1;i=1;p=1;t=1;w=1 ;; # all flags
		g) g=1 ;;
		i) i=1 ;;
		p) p=1 ;;
		t) t=1 ;;
		w) w=1 ;;
		?) echo "usage: currstat.sh [-agiptw] <username>" ;;
	    esac
        fi
    done
fi

### Program functionality

# Start mass error handling:
(

# Output real name of user, position
echo "Current status of $user, AKA \c"
fullName=`finger $user | grep -m 1 "In real life:" | sed -e 's/.*In real life: //'` # Real name
echo  "$fullName""\c" # So that echo doesn't make newline

# Position
# Use id command and parse out group ID to get position (student, faculty, etc.)
fullPosition=`id $user | sed -e 's/uid=.*(//g' | sed -e 's/)//'`
echo ", in group \"$fullPosition\":"
echo # new line

# whois search
# Check flag -w - if it exists run `whois <fullname formatted with no spaces>` and check output for "No match" -> Output false, otherwise output true.
if [ $w -eq 1 ]; then
    nameWithoutSpaces=`echo $fullName | sed 's/ //'`
    whoisResult=`whois $nameWithoutSpaces | grep "No match"`
    if [ ! -n "$whoisResult" ]; then
	echo "This user has a domain name named after them."
    else
	echo "This user does not have a domain name named after them."
    fi
    echo # new line
fi

# Output last processes they started
# Check flag -p - if it exists we output last 10 rather than last 3
# N.B.: These will display the date if they are more than a day old (and may cause order problems)

if [ $p -eq 0 ]; then
echo "Up to 3 most recent commands:"
ps -u $user -o "stime pid comm" | sort -k 1 -r | cut -d " " -f 2- | sed -n '2,4p'
else
echo "Up to 10 most recent commands:"
ps -u $user -o "stime pid comm" | sort -k 1 -r | cut -d " " -f 2- | sed -n '2,11p'
fi
echo # new line

lineCounter=`ps -u $user | wc -l` # For use with error handling involving process output

# If -g flag is set output processes with greatest virtual memory and page usage
if [ $g -eq 1 ]; then

    # Check if user has NO processes
    if [ $lineCounter -eq 1 ]; then
	echo "User has no processes."
    else
	echo "Process with greatest virtual memory usage:"
	ps -u $user -o "comm rss" | sort -k 2 -n -r | sed -e 's/  */\ /g' | head -n 1
	echo "Process with most pages open:"
	ps -u $user -o "comm osz" | sort -k 2 -n -r | sed -e 's/  */\ /g' | head -n 1
	echo # new line
    fi
fi

# If -t flag is set simply output pstree -u $user
if [ $t -eq 1 ]; then
    if [ $lineCounter -eq 1 ]; then
	:
    else
	echo "Process tree for $user:"
	pstree -u $user    
	echo # new line
    fi
fi

# Get time user logged on
# Display message if user isn't on the server

onServer=`who -u | grep $user`
if [ ! -n "$onServer" ]; then
    echo "User is not on the server."
else
    echo "User has been on the server since: \c"
    who | grep "$user" | sed -n '1,1p' | sed -e 's/  */\ /g' | cut -d " " -f 3- | sed -e 's/(.*)//g'
    # Check flag -i-> if set see if they've been idle:
    if [ $i -eq 1 ]; then
	timeIdle=`who -Tu | grep "$user" | awk '$7 !~ /\./ {print $7}'`
	if [ -n "$timeIdle" ]; then
	    echo "User has been idle: $timeIdle"
	else
	    echo "User is not idle."
	fi
	echo # for new line
    fi

    # Output information about the user using their network address
    # Get ip address from who
    ip=`who | grep "$user" | sed -n '1,1p' | sed 's/.*(//' | sed 's/)//'`
    echo "IP address ($ip) connection instances:\c"
    netstat -n | grep "$ip" | wc -l | sed -e 's/  */\ /g' # Get how many lines their IP address is mentioned on
fi

) 2>errorlog.$$
    if [ -s errorlog.$$ ]; then
	echo "currstat.sh encountered error on run at `date +"%T"`" 1>&2
	cat errorlog.$$ >&2
    else
	rm -f errorlog.$$
        # Exit program normally
	exit 0
    fi 