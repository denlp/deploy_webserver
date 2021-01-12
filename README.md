# deploy_webserver

This Terraform module helps to deploy a web server into AWS

The module is tested and compatible with Terraform v12.0 (it was not tested with any higher version of Terraform)


# How to run

To run the module you should refer to it and input your desired values:

- deploy_name: the name of your deployment without spaces
- deploy_type: httpd or nginx (choose one; httpd is set as default)
- ec2_instance_type: the type of your instance for the web server (t2.micro is set as default)
- asg_instance_desired_size: desired amount of instances in auto scaling group which will be created by default
- asg_instance_min_size: min amount of instances in auto scaling group
- asg_instance_max_size: max amount of instances in auto scaling group
- log_mount_size: size of device which will be mounted to /var/log/ (in GB)
- scale_threshold: percentage of CPU load which triggers scalling out
