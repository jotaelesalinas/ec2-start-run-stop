#!/bin/bash
INSTANCE_ID="your-instance-id".  # e.g. i-12345678901234567
COMMAND_TO_RUN="your-command"    # e.g. ./run.sh
SHUTDOWN_COMMAND="sudo poweroff" # or anything you want, really, e.g. custom ./shutdown.sh, as long as it shuts the instance down
SHUTDOWN_ONLY_IF_SUCCESS=0
SSH_CONN_REFUSED=255

./ec2-ssh.sh -i $INSTANCE_ID $COMMAND_TO_RUN
retcode=$?

if [ $retcode -ne 0 ]; then
    if [ $retcode -ne $SSH_CONN_REFUSED ]; then
        echo "Remote command failed with exit code $retcode"
    else
        echo "Timed out. Retrying ..."
        ./ec2-ssh.sh -i $INSTANCE_ID $COMMAND_TO_RUN
        retcode=$?

        if [ $retcode -ne 0 ]; then
            if [ $retcode -ne $SSH_CONN_REFUSED ]; then
                echo "Remote command failed with exit code $retcode"
            else
                echo "Timed out. Retrying ..."
                ./ec2-ssh.sh -i $INSTANCE_ID $COMMAND_TO_RUN
                retcode=$?

                if [ $retcode -ne 0 ]; then
                    if [ $retcode -ne $SSH_CONN_REFUSED ]; then
                        echo "Remote command failed with exit code $retcode"
                    else
                        echo "Timed out for a third time. Exiting."
                        exit $retcode
                    fi
                fi
            fi
        fi
    fi
fi

if [ $SHUTDOWN_ONLY_IF_SUCCESS -ne 0 ]; fi
    if [ $retcode -eq 0 ]; then
        ./ec2-ssh.sh -i $INSTANCE_ID $SHUTDOWN_COMMAND
    fi
else
    ./ec2-ssh.sh -i $INSTANCE_ID $SHUTDOWN_COMMAND
fi
