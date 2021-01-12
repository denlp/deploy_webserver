variable "deploy_name" {
    type = "string"
    default = "new"
}

variable "deploy_type" {
    type = "string"
    default = "httpd"
}

variable "ec2_instance_type" {
  type = string
  default = "t2.micro"
}

variable "asg_instance_max_size"{
  type = number
  default = 2
}

variable "asg_instance_min_size"{
  type = number
  default = 1
}

variable "asg_instance_desired_size"{
  type = number
  default = 1
}

variable "log_mount_device"{
  type = string
  default = "/dev/xvdb"
}

variable "log_mount_size"{
  type = number
  default = 5
}

variable "scale_threshold_type"{
  type = string
  default = "ASGAverageCPUUtilization"
}

variable "scale_threshold"{
  type = number
  default = 75.0
}


###
#Get all AZ withing the region
###
data "aws_availability_zones" "list_all" {
  all_availability_zones = true
}

###
#Get the latest AMI from Amazon
###
data "aws_ami" "latest_amazon_ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}



data "aws_kms_alias" "ebs" {
  name = "alias/aws/ebs"
}


###
#Creating default vpc for the deployment
###
resource "aws_vpc" "default_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      Name = "${var.deploy_name}_${var.deploy_type}_vpc"
      Deployment = "${var.deploy_name}_${var.deploy_type}"
    }
}


###
#Creating internet gateway to enable internet access
###
resource "aws_internet_gateway" "default_igw" {
  vpc_id = aws_vpc.default_vpc.id

  tags = {
    Name = "${var.deploy_name}_${var.deploy_type}_igw"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
  }

  depends_on = [aws_vpc.default_vpc]
}


###
#Creating subnet(s) which should be public
###
resource "aws_subnet" "public_subnet" {
  count = "${length(data.aws_availability_zones.list_all.names)}"       #Creating subnet per AZ
  vpc_id = aws_vpc.default_vpc.id
  cidr_block = "10.0.${255 - count.index}.0/24"
  availability_zone = "${data.aws_availability_zones.list_all.names[count.index]}"      #Each subnet in different AZ (ALB needs at least 2 AZ)

  tags = {
    Name = "public_${count.index + 1}_${var.deploy_name}_${var.deploy_type}_subnet"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
    Type = "public"
  }

  depends_on = [aws_vpc.default_vpc]
}


###
#Creating subnet(s) which should be private
###
resource "aws_subnet" "private_subnet" {
  count = 1 #Creating only 1 private subnet
  vpc_id = aws_vpc.default_vpc.id
  cidr_block = "10.0.${count.index + 1}.0/24"
  availability_zone = "${data.aws_availability_zones.list_all.names[count.index]}"

  tags = {
    Name = "private_${count.index + 1}_${var.deploy_name}_${var.deploy_type}_subnet"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
    Type = "private"
  }

  depends_on = [aws_vpc.default_vpc]
}


###
#Creating route table with route to IGW
###
resource "aws_route_table" "public_subnet_rt" {
  vpc_id = aws_vpc.default_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default_igw.id
  }

  tags = {
    Name = "igw_${var.deploy_name}_${var.deploy_type}_rt"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
    Purpose = "public subnets"
  }

  depends_on = [aws_vpc.default_vpc, aws_internet_gateway.default_igw]
}


###
#Assosiating subnets (which should be public) to routetable with route to IGW
###
resource "aws_route_table_association" "public_subnet" {
  count = "${length(aws_subnet.public_subnet.*.id)}"
  subnet_id = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_subnet_rt.id

  depends_on = [aws_subnet.public_subnet, aws_route_table.public_subnet_rt]
}


###
#Creating elastic IP for NAT
###
resource "aws_eip" "nat" {
  vpc = true
}


###
#Creating NAT to enable outbound connection from private subnet
#Can be in any public subnet within VPC thus assigning it to the one with index 0
###
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public_subnet.0.id      #Assign to any/first public subnet

  depends_on = [aws_vpc.default_vpc, aws_subnet.public_subnet]
}


###
#Creating route table with route to NAT
###
resource "aws_route_table" "private_subnet_rt" {
  vpc_id = aws_vpc.default_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "nat_${var.deploy_name}_${var.deploy_type}_rt"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
    Purpose = "private subnets"
  }

  depends_on = [aws_vpc.default_vpc, aws_nat_gateway.nat]
}


###
#Assosiating subnets (which should be private) to routetable with route to NAT
###
resource "aws_route_table_association" "private_subnet" {
  count = "${length(aws_subnet.private_subnet.*.id)}"
  subnet_id = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_subnet_rt.id

  depends_on = [aws_subnet.private_subnet, aws_route_table.private_subnet_rt]
}


###
#Creating security group for application load balancer
###
resource "aws_security_group" "alb_sg" {
  name = "alb_${var.deploy_name}_${var.deploy_type}_sg"
  description = "security group for application load balancer"
  vpc_id = aws_vpc.default_vpc.id

  ingress {
    description = "HTTP traffic from everywhere"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]    #Allow public end users hit the LB
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [aws_subnet.private_subnet.0.cidr_block]   #Allow connection to private subnet (update this if more private subnets!)
  }

  tags = {
    Name = "alb_${var.deploy_name}_${var.deploy_type}_sg"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
    Purpose = "ALB"
  }

  depends_on = [aws_vpc.default_vpc, aws_subnet.private_subnet]
}

###
#Creating target groups
###
resource "aws_lb_target_group" "web_server_tg" {
  name = "${var.deploy_name}-${var.deploy_type}-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.default_vpc.id

  depends_on = [aws_vpc.default_vpc]
}


###
#Creating application load balancer
###
resource "aws_lb" "alb" {
  name = "${var.deploy_name}-${var.deploy_type}-alb"
  internal  = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = aws_subnet.public_subnet.*.id

  tags = {
    Name = "${var.deploy_name}_${var.deploy_type}_alb"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
  }

  depends_on = [aws_subnet.public_subnet, aws_security_group.alb_sg, aws_route_table_association.public_subnet]
}

###
#Attaching listener to application load balancer
###
resource "aws_lb_listener" "alb_web_server_tg" {
  load_balancer_arn = aws_lb.alb.arn
  port = "80"
  protocol  = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web_server_tg.arn
  }

  depends_on = [aws_lb_target_group.web_server_tg, aws_lb.alb]
}



###
#Creating security group for ec2 within asg
###
resource "aws_security_group" "asg_sg" {
  name = "asg_${var.deploy_name}_${var.deploy_type}_sg"
  description = "security group for web server"
  vpc_id = aws_vpc.default_vpc.id

  dynamic "ingress" {
    iterator = subnet_cidr
    for_each = aws_subnet.public_subnet.*.cidr_block
    content{
      description = "HTTP traffic from public subnet"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["${subnet_cidr.value}"]
    }
  }

  dynamic "ingress" {
    iterator = subnet_cidr
    for_each = aws_subnet.public_subnet.*.cidr_block
    content{
      description = "SSH traffic from public subnet"
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["${subnet_cidr.value}"]   #To be able to ssh to instance
    }
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   #Allow download updates on the instance
  }
  
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  #Allow download updates on the instance
  }

  tags = {
    Name = "asg_${var.deploy_name}_${var.deploy_type}_sg"
    Deployment = "${var.deploy_name}_${var.deploy_type}"
    Purpose = "ASG"
  }

  depends_on = [aws_vpc.default_vpc]
}



###
#Creating launch template for autoscaling groups
###
resource "aws_launch_template" "lt_web_server_ec2" {
  name = "${var.deploy_name}_${var.deploy_type}_lt"
  image_id = data.aws_ami.latest_amazon_ami.id
  instance_type = "${var.ec2_instance_type}"
  #key_name = "linux"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      encrypted = true
      kms_key_id = data.aws_kms_alias.ebs.id
    }
  }

  block_device_mappings {
    device_name = "/dev/sdb"
    ebs {
      volume_size = "${var.log_mount_size}"
      delete_on_termination = true
      encrypted = true
      kms_key_id = data.aws_kms_alias.ebs.id
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    subnet_id = aws_subnet.private_subnet.0.id
    security_groups  = [aws_security_group.asg_sg.id]
  }

  #user_data = filebase64("${path.module}/scripts/init-httpd.sh")
  #user_data = "${base64encode(data.template_file.user_data.rendered)}"
  user_data = base64encode("${templatefile("./deploy_webserver/scripts/init-httpd.sh", {web_server="${var.deploy_type}", mount_device = "${var.log_mount_device}", mount_path = "/var/log/"})}")
  

  depends_on = [aws_security_group.asg_sg, aws_subnet.private_subnet]
}

###
#Creating autoscaling group and attaching launching template
###
resource "aws_autoscaling_group" "lt_web_server_ec2" {
  name = "ec2_web_server_${var.deploy_name}_${var.deploy_type}_lt"
  max_size = "${var.asg_instance_max_size}"
  min_size = "${var.asg_instance_min_size}"
  health_check_grace_period = 300
  health_check_type = "ELB"
  desired_capacity = "${var.asg_instance_desired_size}"
  force_delete  = true
  vpc_zone_identifier = [aws_subnet.private_subnet.0.id] 

  launch_template {
    id  = aws_launch_template.lt_web_server_ec2.id
    version = "$Latest"
  }

  depends_on = [aws_launch_template.lt_web_server_ec2, aws_subnet.private_subnet]
}


###
#Attaching application load balancer to autoscaling group
###
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.lt_web_server_ec2.id
  alb_target_group_arn   = aws_lb_target_group.web_server_tg.arn
  depends_on = [aws_lb_target_group.web_server_tg, aws_autoscaling_group.lt_web_server_ec2] 
}


resource "aws_autoscaling_policy" "example" {
  autoscaling_group_name = aws_autoscaling_group.lt_web_server_ec2.name
  name = "${var.deploy_name}_${var.deploy_type}_asg_policy"
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "${var.scale_threshold_type}"
    }
    target_value = "${var.scale_threshold}"
  }
}

output "alb_hostname" {
  value = aws_lb.alb.dns_name
}















