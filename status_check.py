#!/usr/bin/python3.6
import boto3

def handler(event, context):
    sns = boto3.client('sns')
    ec2 = boto3.client('ec2')

    instances = ec2.describe_instance_status()['InstanceStatuses']

    failed_instances = []

    for instance in instances:
        # collect instances with no tags
        if(instance['InstanceStatus']['Status'] != "ok"):
            failed_instances.append(
                    "{}".format(
                    instance['InstanceId']
                    )
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
