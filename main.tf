# creating vpc
resource "aws_vpc" "vpc_prac" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = var.vpc_name
  }
}
#provisioning 4 subnets with different cidr block specifications
#putting each subnet in different availability zones to make resource highly available
resource "aws_subnet" "test-public-sub1" {
  vpc_id     = aws_vpc.vpc_prac.id
  cidr_block = var.pub_cidr_block_1
  availability_zone = var.az-a

  tags = {
    Name = var.pub_name1
  }
}


resource "aws_subnet" "test-public-sub2" {
  vpc_id     = aws_vpc.vpc_prac.id
  cidr_block = var.pub_cidr_block_2
  availability_zone = var.az-b

  tags = {
    Name = var.pub_name2
  }
}

resource "aws_subnet" "test-priv-sub1" {
  vpc_id     = aws_vpc.vpc_prac.id
  cidr_block = var.priv_cidr_block_1
  availability_zone = var.az-c

  tags = {
    Name = var.priv_name1
  }
}

resource "aws_subnet" "test-priv-sub2" {
  vpc_id     = aws_vpc.vpc_prac.id
  cidr_block = var.priv_cidr_block_2
  availability_zone = var.az-c

  tags = {
    Name = var.priv_name2
  }
}

#provisioning  2 route table for public and private traffic/commun
resource "aws_route_table" "test-pub-route-table" {
  vpc_id = aws_vpc.vpc_prac.id

  tags = {
    Name = var.pub-rt
  }
}

resource "aws_route_table" "test-priv-route-table" {
  vpc_id = aws_vpc.vpc_prac.id

  tags = {
    Name = var.priv-rt
  }
}

#internet gateway provision
resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.vpc_prac.id

  tags = {
    Name = var.igw
  }
}

# route table association with the subnets, 2 subnets to each route table
resource "aws_route_table_association" "public-rta-a" {
  subnet_id      = aws_subnet.test-public-sub1.id
  route_table_id = aws_route_table.test-pub-route-table.id
}

resource "aws_route_table_association" "public-rta-b" {
  subnet_id      = aws_subnet.test-public-sub2.id
  route_table_id = aws_route_table.test-pub-route-table.id
}

resource "aws_route_table_association" "private-rta-a" {
  subnet_id      = aws_subnet.test-priv-sub1.id
  route_table_id = aws_route_table.test-priv-route-table.id
}

resource "aws_route_table_association" "private-rta-b" {
  subnet_id      = aws_subnet.test-priv-sub2.id
  route_table_id = aws_route_table.test-priv-route-table.id
}

# internet gateway route association to route table
resource "aws_route" "test-igw-association" {
  route_table_id            = aws_route_table.test-pub-route-table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id     = aws_internet_gateway.test-igw.id
}

#provisioning elastic ip to associate with the nat gateway
resource "aws_eip" "test-eip" {
  vpc      = true

  
  tags = {
    Name = var.eip-name
  }
}

#provisioning nat gateway
resource "aws_nat_gateway" "test-Nat-gateway" {
  allocation_id = "${aws_eip.test-eip.id}"
  subnet_id     = aws_subnet.test-priv-sub1.id

  tags = {
    Name = var.nat-gw
  }
}


#associating  the Nat gateway with the private route table
resource "aws_route" "test-Nat-association" {
  route_table_id            = aws_route_table.test-priv-route-table.id
  destination_cidr_block    = var.nat-gw-cidr-block        #public Nat gateway
  gateway_id                = aws_nat_gateway.test-Nat-gateway.id
}



#creating security group with port 80 (http) and 22(ssh)

resource "aws_security_group" "test-sec-group" {
  name = var.sg-name
  description = "Allow HTTP and SSH traffic"
  vpc_id      = "${aws_vpc.vpc_prac.id}"

#inbound traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
#outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

 tags = {
    Name = var.sg-name
  } 
}


#creating key pair
#private key
##Creates a PEM (and OpenSSH) formatted private key
resource "tls_private_key" "private-test-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#Generates a local file (on pc) with the given content
resource "local_file" "local-test-key" {
    content  = tls_private_key.private-test-key.private_key_pem
    filename = var.key-pair-name
}

#public key for ssh
resource "aws_key_pair" "test-key" {
  key_name   = var.key-pair-name
  public_key =  tls_private_key.private-test-key.public_key_openssh
}

#creating an IAM policy
resource "aws_iam_policy" "test-iam-policy" {
  name = var.iam-policy-name

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "ec2:*",
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "elasticloadbalancing:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "cloudwatch:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "autoscaling:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": [
                        "autoscaling.amazonaws.com",
                        "ec2scheduled.amazonaws.com",
                        "elasticloadbalancing.amazonaws.com",
                        "spot.amazonaws.com",
                        "spotfleet.amazonaws.com",
                        "transitgateway.amazonaws.com"
                    ]
                }
            }
        }
    ]
})
}

#creating iam roles for ec2 
resource "aws_iam_role" "test-ec2-role" {
  name = var.iam-role-name

  # Terraform's "jsonencode" function converts a Terraform expression result to valid JSON syntax.
  #policy of AmazonEC2FullAccess from console
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  
}

# Attaching the IAM policy to the IAM role
resource "aws_iam_policy_attachment" "test-role-policy-attachment" {
  name = "test-role-policy-attachment"
  policy_arn = aws_iam_policy.test-iam-policy.arn
  roles       = [aws_iam_role.test-ec2-role.name]
}


#attaching iam role to instance profile
resource "aws_iam_instance_profile" "test-profile" {
  name = "test-profile"
  role = aws_iam_role.test-ec2-role.id
}



#provisioning 2 free tier ec2 using ubuntu ami

#putting this ec2 in the private subnet
resource "aws_instance" "test-compute-1" {
  #Ubuntu Server 20.04 LTS (HVM) with SQL Server 2022 Standard
  ami           = var.ami-spec     
  instance_type = var.instance-type
  vpc_security_group_ids = ["${aws_security_group.test-sec-group.id}"]
  key_name               = "${aws_key_pair.test-key.id}"
  subnet_id              = "${aws_subnet.test-priv-sub1.id}"
  iam_instance_profile   = aws_iam_instance_profile.test-profile.id
  
   tags = {
    Name = var.compute-name1
  }
}

#for the public
resource "aws_instance" "test-compute-2" {
  #ami: Ubuntu Server 20.04 LTS (HVM) with SQL Server 2022 Standard
  ami           = var.ami-spec 
  instance_type = var.instance-type
  vpc_security_group_ids = ["${aws_security_group.test-sec-group.id}"]
  key_name               = "${aws_key_pair.test-key.id}"
  subnet_id              = element(var.compute-pub-sub-id, count.index)
  iam_instance_profile   = aws_iam_instance_profile.test-profile.id
  count                  = var.instance-no
  associate_public_ip_address = true
  user_data = <<-EOF
      #!/bin/bash
      sudo apt update -y
      sudo yum install httpd -y
      sudo systemctl start httpd
      sudo systemctl enable httpd
      sudo apt install apache2 -y
      sudo systemctl start apache2
      sudo systemctl enable apache2
      sudo apt install git -y
      git clone https://github.com/palakbhawsar98/FirstWebsite.git
      cd /FirstWebsite
      sudo cp index.html /var/www/html/
      EOF


   tags = {
    Name = element(var.compute-name2, count.index)
  }
}


#spot instance
resource "aws_instance" "test-spot" {
  ami = var.ami-spec
  vpc_security_group_ids = ["${aws_security_group.test-sec-group.id}"]
  key_name               = "${aws_key_pair.test-key.id}"
  instance_market_options {
    spot_options {
      max_price = 0.0021
      spot_instance_type = "one-time"
    }
  }
  instance_type = var.spot-ec2-type
  tags = {
    Name = "test-spot"
  }
}

#ebs for instances

resource "aws_ebs_volume" "dev-public-volume1" {
  availability_zone = var.az-a
  size              = 75

  tags = {
    Name = "dev-public-volume1"
  }
}

resource "aws_ebs_volume" "dev-public-volume1" {
  availability_zone = var.az-b
  size              = 75

  tags = {
    Name = "dev-public-volume2"
  }
}

resource "aws_ebs_volume" "dev-public-volume1" {
  availability_zone = var.az-c
  size              = 50

  tags = {
    Name = "dev-private-volume1"
  }
}

#ebs attachment to instances
resource "aws_volume_attachment" "vol-attach1" {
 device_name = "/dev/sdh"
 volume_id = "${aws_ebs_volume.dev-public-volume1.id}"
 instance_id = "${aws_instance.test-compute-2[count.index].id}"
}

resource "aws_volume_attachment" "vol-attach2" {
 device_name = "/dev/sdh"
 volume_id = "${aws_ebs_volume.dev-public-volume2.id}"
 instance_id = "${aws_instance.test-compute-2[count.index].id}"
}

resource "aws_volume_attachment" "vol-attach3" {
 device_name = "/dev/sdh"
 volume_id = "${aws_ebs_volume.dev-private-volume1.id}"
 instance_id = "${aws_instance.test-compute-1.id}"
}


#autoscaling for ec2 resources
#creating launch for all instances
resource "aws_launch_template" "test-asg-launch-temp" {
  name_prefix   = "test-asg-compute-"
  image_id      = var.ami-spec
  instance_type = var.instance-type
}

resource "aws_launch_configuration" "test-asg-launch-config" {
  name_prefix   = "test-asg-compute-config-"
  image_id      = var.ami-spec
  instance_type = var.instance-type
  security_groups = ["${aws_security_group.test-sec-group.id}"]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "test-asg" {
  availability_zones        = [var.az-a, var.az-b]
  launch_configuration      = aws_launch_configuration.test-asg-launch-config.name
  desired_capacity          = 3
  max_size                  = 8
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB" #will provision load balancer
  force_delete              = true
  termination_policies      = ["OldestInstance"]
  launch_template {
    id      = aws_launch_template.test-asg-launch-temp.id
    version = "$Latest"
  }
}

#the schedule for autoscaling group
resource "aws_autoscaling_schedule" "test-asg-schedule" {
  scheduled_action_name  = "test-asg-schedule"
  min_size               = 1
  max_size               = 8
  desired_capacity       = 3
  start_time             = "2023-05-10T18:00:00Z"
  end_time               = "2023-12-20T06:00:00Z"
  autoscaling_group_name = aws_autoscaling_group.test-asg.name
}

#policy for scaling in or outthe ec2
resource "aws_autoscaling_policy" "asg-policy" {
  name                   = "asg-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 100
  autoscaling_group_name = "${aws_autoscaling_group.test-asg.name}"
}

#Notification for autoscaling actions
resource "aws_sns_topic" "test-asg-actions" {
  name = "test-asg-actions"
}

resource "aws_autoscaling_notification" "test-asg-notifications" {
  group_names = [
    aws_autoscaling_group.test-asg.name,
  ]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]
  topic_arn = aws_sns_topic.test-asg-actions.arn
}



#provisioning load balancer  with the autoscaling group  
# to make the ec2 (resources) highly available and efficient

resource "aws_lb" "test-lb" {
  name               = "test-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.test-sec-group.id}"]
  subnets            = element(var.compute-pub-sub-id, count.index)
}


resource "aws_lb_listener" "test-lb-listener" {
  load_balancer_arn = aws_lb.test-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test-lb-target-group.arn
  }
}

resource "aws_lb_target_group" "test-lb-target-group" {
   name     = "test-lb-target-group"
   port     = 80
   protocol = "HTTP"
   vpc_id   = aws_vpc.vpc_prac.id
 }

resource "aws_autoscaling_attachment" "test-asg-lb-attachment" {
  autoscaling_group_name = aws_autoscaling_group.test-asg.id
  alb_target_group_arn   = aws_lb_target_group.test-lb-target-group.arn
}



