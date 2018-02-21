#!/usr/bin/python3.6
import boto3


def format_instance_details(instance):
    try:
        instance_name = [x for x in instance.tags if x['Key'] == 'Name'][0]['Value']
    except:
        instance_name = ''

    try:
        instance_team = [x for x in instance.tags if x['Key'].lower() == 'team'][0]['Value']
    except:
        instance_team = ''

    try:
        instance_environment = [x for x in instance.tags if x['Key'].lower() == 'environment'][0]['Value']
    except:
        instance_environment = ''

    formatted_string = "{} \t type: '{}' \t\t name: '{}' \t\t team: '{}' \t environment: '{}'".format(
            instance.instance_id,
            instance.instance_type,
            instance_name,
            instance_team,
            instance_environment
            )

    return formatted_string


def status_check(ec2, instance_id):
  status_check_failed = False
  instance_status = ec2.describe_instance_status(InstanceIds=[instance_id])['InstanceStatuses'][0]['InstanceStatus']['Status']
  if instance_status != 'ok':
      status_check_failed = True
  return status_check_failed

def handler(event, context):
    sns = boto3.client('sns')
    ec2 = boto3.client('ec2')
    # create filter for instances in running state
    filters = [
        {
            'Name': 'instance-state-name',
            'Values': ['running']
        }
    ]

    instances = [i for i in boto3.resource('ec2').instances.filter(Filters=filters)]

    failed_instances = []

    for instance in instances:
        # collect instances with no tags
        if(status_check(ec2, instance.instance_id)):
            failed_instances.append(
                    format_instance_details(instance)
                    )

    # Print instance_id of instances that do not have the Environment tag
    for instance in failed_instances:
        print(instance)

    if event and failed_instances:
        sns.publish(
                TopicArn=event['topic'],
                Message="\n".join(failed_instances),
                Subject="EC2 Instance Status Check Failed"
                )


if __name__ == "__main__":
    handler(event={}, context=None)
