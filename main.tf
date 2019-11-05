# main code for terraform automation of deployment of running app
# all variables interpolated for abstraction reasons and security reasons so this could be posted to github with a .gitignore

# set the provider

provider "aws" {
  region = "eu-west-1"
}

# launch the subnet you want your instance to be in

resource "aws_subnet" "app_subnet" {
  vpc_id     = "${var.vpc_id}"
  cidr_block = "${var.cidr_block}"
  tags = {
    Name = "${var.name}_app_subnet"
  }
}

# launch first ec2 instance
# assign it to the created subnet

resource "aws_instance" "app_instance" {
  ami = "${var.app_ami_id}"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.app_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.app_sg.id}"]
  key_name = "${var.ssh_key_name}"
  user_data = "${data.template_file.app_instance.rendered}"
  tags = {
    Name = "${var.name}-app-to-destroy"
  }
}

# launch security group for your instance and assign it in the instance code block

resource "aws_security_group" "app_sg" {
    name = "allow port 80"
    description = "Allow traffic to pass from the private subnet to the internet"

    #define the ports you want to open and from which IPs (with CIDR blocks)
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "open internet port from anywhere"
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.LW_IP}"]
        description = "open ssh port from london wall"
    }
    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["${var.LW_IP}"]
        description = "open 3000 port from london wall"
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.SAM_IP}"]
        description = "open ssh port from sam home"
    }
    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["${var.SAM_IP}"]
        description = "open 3000 port from sam home"
    }

    # set the vpc you want to use

    vpc_id = "${var.vpc_id}"

    tags = {
      Name = "${var.name}-app_security_group"
    }
}

# set the route table
resource "aws_route_table" "app_route_table" {
    vpc_id = "${var.vpc_id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${data.aws_internet_gateway.default.id}"
    }

    tags = {
        Name = "${var.name}-Public-route-table"
    }
}

# associate the route table with a subnet

resource "aws_route_table_association" "app_route_assoc" {
    subnet_id = "${aws_subnet.app_subnet.id}"
    route_table_id = "${aws_route_table.app_route_table.id}"
}


# Data command (get data from the aws service, store it to a variable)
# Grab a reference to the internet gateway_id for our vpc
# assign it to the route table back up in that block of code

data "aws_internet_gateway" "default" {
  filter {
    name = "attachment.vpc-id"
    values = ["${var.vpc_id}"]
  }
}

# sending script for bash commands (See init.sh.tpl file in scripts/)
data "template_file" "app_instance" {
  template = "${file("./scripts/app/init.sh.tpl")}"
}

# set an ssh key, with the name, and provide it with the public key for that pair.
# Make sure you have the private part saved as a .pem for it in case you need to access it

resource "aws_key_pair" "deployer" {
  key_name   = "${var.ssh_key_name}"
  public_key = "${var.ssh_public_key}"
}
