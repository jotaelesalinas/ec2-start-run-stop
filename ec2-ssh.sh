#!/bin/bash
set -u

# Starts an EC2 instance _if needed_ and runs an SSH command or opens a shell.

# Summary of steps:
# 1. Checks current instance status
# 2. Starts instance if needed
# 3. Waits for the instance to be ready (status "running")
# 4. Connects via SSH, possibly running a command

DEFAULT_INSTANCE_ID="0"
DEFAULT_USERNAME="ubuntu"
DEFAULT_PEM_FILE="0"
DEFAULT_WAIT_SECONDS=15
DEFAULT_USE_PRIVATE_IP=0
DEFAULT_ONLY_STATUS=0

# do not modify!
# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instance-status.html
STATUS_CODE_TERMINATED=48
STATUS_CODE_SHUTTING_DOWN=32
STATUS_CODE_STOPPING=64
STATUS_CODE_STOPPED=80
STATUS_CODE_PENDING=0
STATUS_CODE_RUNNING=16

# do not modify!
# https://www.cyberciti.biz/faq/what-are-the-exit-statuses-of-ssh-command/
SSH_CONN_REFUSED=255

function error () {
    echo "" >&2
    echo "Error: $1" >&2
    exit $2
}

############################################################################
# usage and read arguments
############################################################################

function usage () {
    __USAGE="Usage:
$(basename $0) -i <EC2 instance id> -s
$(basename $0) -i <EC2 instance id> [options] <remote command and arguments>

Where:
    -i <EC2 instance id> specifies the instance ID of your EC2 instance --not image.

Options:
    -s: switch to show the instance status and IP addresses, if any.
        No SSH connection is done if this switch is present.
    -k <pem file>: location of the PEM file with the SSH key. Default:
        ec2-<instance id>[<other things>].pem in the working directory.
    -u <username>: username of remote host. default: $DEFAULT_USERNAME.
    -w <seconds>: number of seconds to wait before connecting. default: $DEFAULT_WAIT_SECONDS.
    -p: switch to use private IP address instead of public.
    <remote command and arguments> is anything you want to run on the remote server.
        Optional. If missing, you will start an interactive session with the default shell.
"

    if [[ $# -gt 0 ]]; then
        echo "Error: $1" >&2
        echo "" >&2
    fi
    echo "$__USAGE" >&2
    exit 1;
}

INSTANCE_ID=$DEFAULT_INSTANCE_ID
USERNAME=$DEFAULT_USERNAME
PEM_FILE=$DEFAULT_PEM_FILE
WAIT_SECONDS=$DEFAULT_WAIT_SECONDS
USE_PRIVATE_IP=$DEFAULT_USE_PRIVATE_IP
ONLY_STATUS=$DEFAULT_ONLY_STATUS

while getopts ":i:k:w:u:ps" VARNAME; do
    case $VARNAME in
        i)
            INSTANCE_ID="$OPTARG"
            ;;
        k)
            PEM_FILE="$OPTARG"
            ;;
        u)
            USERNAME="$OPTARG"
            ;;
        w)
            WAIT_SECONDS="$OPTARG"
            ;;
        p)
            USE_PRIVATE_IP=1
            ;;
        s)
            ONLY_STATUS=1
            ;;
        \?)
            usage "Invalid option -$OPTARG"
            ;;
        :)
            usage "Option -$VARNAME requires a parameter."
            ;;
    esac
done

# remove all options from the argument list
shift $((OPTIND - 1))

############################################################################
# some checks
############################################################################

if [ $INSTANCE_ID == $DEFAULT_INSTANCE_ID ]; then
    usage "Missing instance id" 1
fi

if [ $ONLY_STATUS -ne 1 ]; then
    if [ $PEM_FILE == $DEFAULT_PEM_FILE ]; then
        NUM_PEM_FILES=`ls ec2-$INSTANCE_ID*.pem | wc -l`
        if [ $NUM_PEM_FILES -eq 0 ]; then
            usage "No PEM file found matching ec2-$INSTANCE_ID....pem" 1
        elif [ $NUM_PEM_FILES -gt 1 ]; then
            usage "More than one PEM file found matching ec2-$INSTANCE_ID....pem" 1
        fi
        PEM_FILE=`ls ec2-$INSTANCE_ID*.pem | head -n 1`
    fi

    if [ ! -f $PEM_FILE ]; then
        usage "PEM file $PEM_FILE does not exist." 1
    fi
fi

which aws > /dev/null 2> /dev/null
if [ $? -ne 0 ]; then
    error "Missing command aws" 2
fi

which jq > /dev/null 2> /dev/null
if [ $? -ne 0 ]; then
    error "Missing command jq" 2
fi

############################################################################
# 1. get initial status
############################################################################

function remove_quotes () {
    echo $1 | sed -e 's/^"//' -e 's/"$//'
}

function status () {
    # $1 is the instance id
    if [ -z $1 ]; then
        error "Missing instance id in status() function" 3
    fi

    STATUS_JSON=`aws ec2 describe-instances --instance-id $1`
    if [ $? -ne 0 ]; then
        error "Could not retrieve instance status" 3
    fi

    STATUS_STATE_CODE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].State.Code'`
    
    STATUS_STATE_NAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].State.Name'`
    STATUS_STATE_NAME=`remove_quotes $STATUS_STATE_NAME`
    
    STATUS_PUBLIC_IP=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PublicIpAddress'`
    STATUS_PUBLIC_IP=`remove_quotes $STATUS_PUBLIC_IP`
    if [ $STATUS_PUBLIC_IP == "null" ]; then
        STATUS_PUBLIC_IP=""
    fi

    STATUS_PUBLIC_HOSTNAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PublicDnsName'`
    STATUS_PUBLIC_HOSTNAME=`remove_quotes $STATUS_PUBLIC_HOSTNAME`
    
    STATUS_PRIVATE_IP=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PrivateIpAddress'`
    STATUS_PRIVATE_IP=`remove_quotes $STATUS_PRIVATE_IP`
    
    STATUS_PRIVATE_HOSTNAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PrivateDnsName'`
    STATUS_PRIVATE_HOSTNAME=`remove_quotes $STATUS_PRIVATE_HOSTNAME`

    INSTANCE_KEY_NAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].KeyName'`
    INSTANCE_KEY_NAME=`remove_quotes $INSTANCE_KEY_NAME`
    INSTANCE_TYPE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].InstanceType'`
    INSTANCE_TYPE=`remove_quotes $INSTANCE_TYPE`

    INSTANCE_ZONE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].Placement.AvailabilityZone'`
    INSTANCE_ZONE=`remove_quotes $INSTANCE_ZONE`
}

status $INSTANCE_ID

############################################################################
# show small summary
############################################################################

echo "==========================================================================="
echo "= Instance ID:   $INSTANCE_ID"
echo "= Key name:      $INSTANCE_KEY_NAME"
echo "= Instance type: $INSTANCE_TYPE"
echo "= Avail. zone:   $INSTANCE_ZONE"
echo "==========================================================================="

############################################################################
# show status and exit
############################################################################

if [ $ONLY_STATUS -eq 1 ]; then
    echo ""
    echo "State:        $STATUS_STATE_CODE ($STATUS_STATE_NAME)"
    echo "Public IP:    $STATUS_PUBLIC_IP"
    echo "Public host:  $STATUS_PUBLIC_HOSTNAME"
    echo "Private IP:   $STATUS_PRIVATE_IP"
    echo "Private host: $STATUS_PRIVATE_HOSTNAME"
    exit
fi

############################################################################
# check current status
############################################################################

if [ $STATUS_STATE_CODE -eq $STATUS_CODE_TERMINATED ]; then
    error "Instance is terminated" 4
elif [ $STATUS_STATE_CODE -eq $STATUS_CODE_SHUTTING_DOWN ]; then
    error "Instance is shuttung down" 4
elif [ $STATUS_STATE_CODE -eq $STATUS_CODE_STOPPING ]; then
    error "Instance is stopping" 4
elif [ $STATUS_STATE_CODE -eq $STATUS_CODE_RUNNING ]; then
    echo ""
    echo "Instance is already running."
elif [ $STATUS_STATE_CODE -eq $STATUS_CODE_PENDING ]; then
    echo ""
    echo "Instance is starting."
elif [ $STATUS_STATE_CODE -eq $STATUS_CODE_STOPPED ]; then
    echo ""
    echo "Instance is stopped."
else
    error "Unknown instance state $STATUS_STATE_CODE ($STATUS_STATE_NAME)" 5
fi

############################################################################
# 2. start if needed
############################################################################

if [ $STATUS_STATE_CODE -eq $STATUS_CODE_STOPPED ]; then
    echo ""
    echo "Starting instance..."
    aws ec2 start-instances --instance-ids i-01a10364fa24c3509 | cat -

    if [ ! $? -eq 0 ]; then
        error "aws ec2 start-instances failed." 6
    fi

    sleep 1
fi

############################################################################
# 3. recheck status until it is "running"
############################################################################

while [ ! $STATUS_STATE_CODE -eq $STATUS_CODE_RUNNING ]; do
    status $INSTANCE_ID

    if [ $STATUS_STATE_CODE -eq $STATUS_CODE_STOPPED ]; then
        error "Instance is still stopped." 7
    elif [ $STATUS_STATE_CODE -eq $STATUS_CODE_PENDING ]; then
        printf "."
        sleep 1
    elif [ $STATUS_STATE_CODE -eq $STATUS_CODE_RUNNING ]; then
        printf "\n"
        echo "Up and running!"
    else
        error "Unexpected instance state $STATUS_STATE_CODE ($STATUS_STATE_NAME)" 8
    fi
done

############################################################################
# 4. connect
############################################################################

echo "Waiting $WAIT_SECONDS seconds..."
sleep $WAIT_SECONDS

if [ $USE_PRIVATE_IP -eq 1 ]; then
    IP_ADDRESS=$STATUS_PRIVATE_IP
else
    IP_ADDRESS=$STATUS_PUBLIC_IP
fi

echo ""
echo "Connecting..."
echo "---------------------------------------------------------------------------"
echo "- IP address: $IP_ADDRESS"
echo "- User:       $USERNAME"
echo "- PEM file:   $PEM_FILE"
echo "- Arguments:  $*"
echo "---------------------------------------------------------------------------"
echo ""
ssh -i $PEM_FILE -o StrictHostKeyChecking=no $USERNAME@$IP_ADDRESS $*

RETCODE=$?
if [ $RETCODE -eq $SSH_CONN_REFUSED ]; then
    error "SSH connection failed." $RETCODE
fi

echo ""
echo "Done! Return code: " $RETCODE
