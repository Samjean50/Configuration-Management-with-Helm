# Define the AWS provider configuration.
provider "aws" {
  region = "us-east-1" # Replace with your desired AWS region.
}

resource "aws_key_pair" "helm-key" {
  key_name   = "terraform-demo-samjean"
  public_key = file(pathexpand("~/.ssh/helm-terraform-key.pub"))
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "Web-sg"
  }
}

resource "aws_instance" "server" {
  ami                    = "ami-0b6c6ebed2801a5cb"
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.helm-key.key_name
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id

  tags = {
    Name = "Jenkins-Helm-Server"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(pathexpand("~/.ssh/helm-terraform-key"))
    host        = self.public_ip
    timeout     = "15m"
  }

  # Upload the installation script
  provisioner "file" {
    source      = "install.sh"
    destination = "/home/ubuntu/install.sh"
  }

    # File provisioner to copy a file from local to the remote EC2 instance
  provisioner "file" {
    source      = "/Users/celeb/Documents/DAREY/Terrafom-Demo/install.sh"  # Replace with the path to your local file
    destination = "/home/ubuntu/install.sh"  # Replace with the path on the remote instance
  }

  # Execute the installation script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install.sh",
      "/home/ubuntu/install.sh 2>&1 | tee /home/ubuntu/install.log"
    ]
  }
}

# resource "aws_s3_bucket" "s3_bucket" {
#   bucket = "abhishek-s3-demo-xyz" # change this
# }

# resource "aws_dynamodb_table" "terraform_lock" {
#   name           = "terraform-lock"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
