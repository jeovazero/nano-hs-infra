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
    ami           = data.aws_ami.amzn.id
    instance_type = "t3a.nano"
    key_name      = aws_key_pair.jeogod-key.key_name
    tags = {
        Name = "nano-hs"
    }
    depends_on = [aws_key_pair.jeogod-key]
}

/*
resource "aws_eip" "nano_ip" {
    instance  = aws_instance.nano_hs.id
    depends_on = [aws_instance.nano_hs]
}

output "nano_ip" {
  value = aws_eip.nano_ip.public_ip
}
*/
