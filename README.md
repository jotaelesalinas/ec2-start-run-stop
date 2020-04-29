# ec2-start-run-stop

Starts an EC2 instance remotely, runs a command and stops the instance

Because EC2 instances are billed by the second, this is an easy way to perform sporadic or periodic tasks without keeping your instances up and running.

## Installation

Just copy the files in this repo to a local folder.

## Dependencies

You will need `aws-cli` and `jq` installed in your machine.

## Configuration

Edit `ec2-status.sh` and `ec2-start-run-stop.sh` to add the ID of your EC2 image (`INSTANCE_ID`) and the command that you want to run in the instance (`COMMAND_TO_RUN`).

## Usage

Once configured, just run:

```bash
./ec2-start-run-stop.sh
```

Hint: you can add this command to your crontab.
