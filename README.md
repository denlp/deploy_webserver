# deploy_webserver

This Terraform module helps to deploy a web server into AWS

The module is tested and compatible with Terraform v12.0 (it was not tested with any higher version of Terraform)


# Module provisioning output

This module is supposed to provision/configure:

- one defualt vpc
- one defualt private subnet for web server itself
- several public subnets ( correlates with number of AZs in the particular region)
- one internet gateway
- one elastic ip for the NAT
- one NAT
- two route tables: one for public subnets the other for private
- two security groups: one applies to application load balancer the other to any web server instance
- an application load balancer (recieves traffic over HTTP and forwards it to web server over HTTP)
- ec2 instances based on scaling parameters

# Module warnings

- No HTTPS only HTTP (!IMPORTANT: do not use this web server for any sensetive content)
- No Hight Avalaiabilty (web server instance is scaled only in single AZ; but the load balancer is highly avaliable)
- Module is possible to run in region where there is more than on AZ (as at least two AZ are desired for the load balancer)
- Currently it is not possible to provision nginx web server (to be tested to find a root cause)


# How to run

To run the module you should refer to it and input your desired values (also see example main.tf):

- deploy_name: the name of your deployment without spaces
- deploy_type: httpd or nginx (choose one; httpd is set as default)
- ec2_instance_type: the type of your instance for the web server (t2.micro is set as default)
- asg_instance_desired_size: desired amount of instances in auto scaling group which will be created by default
- asg_instance_min_size: min amount of instances in auto scaling group
- asg_instance_max_size: max amount of instances in auto scaling group
- log_mount_size: size of device which will be mounted to /var/log/ (in GB)
- scale_threshold: percentage of CPU load which triggers scalling out

After provisioning check terraform output for details like web server URL

# TO-DO 

- 
