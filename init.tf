terraform {
  backend "remote" {
    organization = "jeovazero"

    workspaces {
      name = "aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "nano-vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Nano VPC"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "nano-subnet" {
  vpc_id            = aws_vpc.nano-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Nano Main Subnet"
  }
}

# Security Group operates at the instance level
resource "aws_security_group" "nano-sec" {
  name   = "nano-sec-main"
  vpc_id = aws_vpc.nano-vpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow TLS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nano Sec Group"
  }
}

# Network ACL operates at the subnet level
resource "aws_network_acl" "nano-acl" {
  vpc_id     = aws_vpc.nano-vpc.id
  subnet_ids = [aws_subnet.nano-subnet.id]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "-1"
    rule_no    = 300
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 310
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "Nano Net ACL"
  }
}

resource "aws_internet_gateway" "nano-gw" {
  vpc_id = aws_vpc.nano-vpc.id
  tags = {
    Name = "Nano Internet Gateway"
  }
}

# The Route Table determines where network traffic from your subnet
# or gateway is directed.
resource "aws_route_table" "nano-rt" {
  vpc_id = aws_vpc.nano-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nano-gw.id
  }

  tags = {
    Name = "Nano Route Table"
  }
}

# The association between a route table and a subnet
resource "aws_route_table_association" "nano-assoc" {
  subnet_id      = aws_subnet.nano-subnet.id
  route_table_id = aws_route_table.nano-rt.id
}

data "aws_ami" "amzn" {
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn-ami-hvm-2018.03.0.20200729.0-x86_64-gp2"]
  }
}

variable "ssh_pub_key" {
  type = string
}

resource "aws_key_pair" "jeogod-key" {
  key_name   = "jeogod-pair"
  public_key = var.ssh_pub_key
}

resource "aws_instance" "nano_hs" {
  ami                    = data.aws_ami.amzn.id
  vpc_security_group_ids = [aws_security_group.nano-sec.id]
  subnet_id              = aws_subnet.nano-subnet.id
  private_ip             = "10.0.1.144"
  instance_type          = "t3.micro"
  associate_public_ip_address = true
  key_name               = aws_key_pair.jeogod-key.key_name
  tags = {
    Name = "nano-hs"
  }
  depends_on = [aws_key_pair.jeogod-key, aws_route_table_association.nano-assoc]
}

resource "aws_eip" "nano_ip" {
    instance  = aws_instance.nano_hs.id
    depends_on = [aws_instance.nano_hs]
}

output "nano_ip" {
  value = aws_eip.nano_ip.public_ip
}