variable "deployment_region" {
    type = "string"
    default = "eu-west-2"
}

provider "aws" {
    region = "${var.deployment_region}"
    access_key = "AKIA2LXJ2KGQF3JF5AEG"
    secret_key = "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"
}

module "deploy_webserver_module" {
    source = "./deploy_webserver"

    #Name the deployment (without spaces)
    deploy_name = "temaplate"

    #Web server name ("httpd"|"nginx") (for now only "httpd" is supported!)
    deploy_type = "httpd"

    #Type of EC2 instance for the web server
    ec2_instance_type = "t2.micro"

    #Desired size of your auto scaling group
    asg_instance_desired_size = 2

    #Min size of your auto scaling group
    asg_instance_min_size = 1

    #Max size of your auto scaling group
    asg_instance_max_size = 5

    #Size of mount for logs
    log_mount_size = 10

    #Threshold value for scaling
    scale_threshold = 70.0
}