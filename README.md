# deploy_webserver_module

This Terraform module helps to deploy a web server into AWS

The module is tested and compatible with Terraform v12.0 (it was not tested with any higher version of Terraform)


# Module provisioning output

This module is supposed to provision/configure:

- one default vpc which also allows further growth (/16 CIDR)
- one default private subnet for web server itself (/24 CIDR)
- several public subnets ( correlates with number of AZs in the particular region) (each /24 CIDR)
- one internet gateway
- one elastic IP for the NAT
- one NAT
- two route tables: one for public subnets the other for private subnet
- two security groups: one applies to application load balancer the other one to any web server instance
- an application load balancer (receives traffic over HTTP and forwards it to web server over HTTP); the alb is located in a public subnet
- one auto scaling group which takes care of scaling web servers
- ec2 instances based on scaling parameters; each located in a private subnet
- one launch template to provision one or more ec2 instances

# Other design details

- The end users can access the web server only through the load balancer via provided URL
- The data on the web server are encrypted (each instance contains two encrypted devices: one for root and the other for all log storage)
- Web server instances are scaled based on the CPU load (the CPU threshold for scaling can be input)
- ALB (application load balancer) security group allows inbound HTTP traffic and outbound HTTP traffic to the public subnet (to be able to forward traffic to the web server itself)
- ASG (auto scaling group) security group allows inbound HTTP (from ALB) and SSH (admin connect) traffic from all the public subnets within VPC and outbound HTTP(S) traffic to any destination (for the matter of updates etc.)
- Instance launch template contains a boot script which: create /var/log mount and installing the web server


# Module flaws

- No HTTPS support for module, only HTTP (!IMPORTANT: do not use this web server for any sensitive content)
- No High Availability (web server instance is scaled only in single AZ; but the load balancer is highly available)
- Module is possible to run in a region where there is more than one AZ (as at least two AZ are desired for the load balancer)
- Currently it is not possible to provision nginx web server (to be tested to find the root cause)
- No web server monitoring and alarming
- No access to administrate web server and its configs as the web servers are in private subnet


# How to run

To run the module you should refer to it and input your desired values (also see example main.tf):

- deploy_name: the name of your deployment without spaces
- deploy_type: httpd or nginx (choose one; httpd is set as default)
- ec2_instance_type: the type of your instance for the web server (t2.micro is set as default)
- asg_instance_desired_size: desired amount of instances in auto scaling group which will be created by default
- asg_instance_min_size: min amount of instances in auto scaling group
- asg_instance_max_size: max amount of instances in auto scaling group
- log_mount_size: size of device which will be mounted to /var/log/ (in GB)
- scale_threshold: percentage of CPU load which triggers scaling out

After provisioning check terraform output for details like web server URL

# TO-DO 

Here is the list of suggestions of how to resolve/mitigate module flows:

- Increasing logs: provision s3, in instance bootstrap script install and configure logrotate to rotate logs when reaching specific size, as postrotate send archived logs to s3 and remove it from filesystem
- High Availability zone: create private subnet per available AZ, and set allow ASG for more AZ/subnets
- Generate random string for deployment name in case it is not supplied
- Enable HTTPS support for the module: provision certificate via ACM for the ALB hostname and automate its approval (include for_each block which is supported from Terraform 12.17), update ALB listener to accept HTTPS traffic and place the certificate on ALB (HTTPS would terminate on the load balancer) + adjust security group to allow HTTPS inbound traffic
- Application monitoring/alarming: with AWS CloudWatch monitor and notify about web server errors in log
- Admin access to web server: ?? on web server provide key pair on provisioning, on the web server configure specific httpd/nginx user which will be able to adjust httpd/nginx configs and restart the web server to apply configs, configure bastion ec2 instance  which would force ssh redirect to the desired web server, set access to bastion instance with AIM Role ???
