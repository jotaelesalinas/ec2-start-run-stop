#!/bin/bash

INSTANCE_ID="your-instance-id"

function error () {
    echo "" >&2
    echo "Error: $1" >&2
    exit $2
}

function remove_quotes () {
    echo $1 | sed -e 's/^"//' -e 's/"$//'
}

which aws > /dev/null 2> /dev/null
if [ $? -ne 0 ]; then
    error "Missing command aws" 2
fi

which jq > /dev/null 2> /dev/null
if [ $? -ne 0 ]; then
    error "Missing command jq" 2
fi

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

echo "==========================================================================="
echo "= Instance ID:   $INSTANCE_ID"
echo "= Key name:      $INSTANCE_KEY_NAME"
echo "= Instance type: $INSTANCE_TYPE"
echo "= Avail. zone:   $INSTANCE_ZONE"
echo "==========================================================================="

echo ""
echo "State:        $STATUS_STATE_CODE ($STATUS_STATE_NAME)"
echo "Public IP:    $STATUS_PUBLIC_IP"
echo "Public host:  $STATUS_PUBLIC_HOSTNAME"
echo "Private IP:   $STATUS_PRIVATE_IP"
echo "Private host: $STATUS_PRIVATE_HOSTNAME"
