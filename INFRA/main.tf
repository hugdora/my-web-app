terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.app_name}-key"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "${var.app_name}-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.app_name}-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "${var.app_name}-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.app_name}-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF2
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1

    sudo apt-get update -y
    sudo apt-get upgrade -y

    sudo apt-get install -y curl git nginx
    sudo curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    sudo apt-get install -y nodejs

    sudo npm install -g pm2

    systemctl enable nginx
    systemctl start nginx

    cd /home/ubuntu
    rm -rf my-web-app

    sudo -u ubuntu git clone https://github.com/hugdora/my-web-app.git /home/ubuntu/my-web-app
    cd /home/ubuntu/my-web-app/APP

    sudo -u ubuntu npm install
    sudo -u ubuntu pm2 start index.js --name my-web-app
    sudo -u ubuntu pm2 save

    env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu

    cat > /etc/nginx/sites-available/my-web-app <<'NGINX'
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
    NGINX

    ln -sf /etc/nginx/sites-available/my-web-app /etc/nginx/sites-enabled/my-web-app
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl reload nginx
  EOF2

  tags = {
    Name = var.app_name
  }
}