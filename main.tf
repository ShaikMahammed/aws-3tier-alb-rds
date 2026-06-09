# ==========================================
#             VPC 
# ==========================================

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = var.vpc_name
  }
}

# ==========================================
#             Subnets
# ==========================================

resource "aws_subnet" "pb01_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pb01_cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = var.pb01_name
  }
}

resource "aws_subnet" "pb02_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pb02_cidr
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = var.pb02_name
  }
}

resource "aws_subnet" "pv01" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.pv01_cidr
  availability_zone = "ap-south-1a"
  tags = {
    Name = var.pv01_name
  }
}

resource "aws_subnet" "pv02" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.pv02_cidr
  availability_zone = "ap-south-1b"
  tags = {
    Name = var.pv02_name
  }
}

# ==========================================
#             Internet Gateway
# ==========================================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = var.igw
  }
}

resource "aws_route_table" "pb_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = var.pb_rt
  }
}

resource "aws_route_table_association" "pb01_assoc" {
  subnet_id      = aws_subnet.pb01_subnet.id
  route_table_id = aws_route_table.pb_rt.id
}

resource "aws_route_table_association" "pb02_assoc" {
  subnet_id      = aws_subnet.pb02_subnet.id
  route_table_id = aws_route_table.pb_rt.id
}

# ==========================================
#             NAT Gateway
# ==========================================

resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "eip"
  }
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.pb01_subnet.id
  allocation_id = aws_eip.eip.id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = var.nat_gw
  }
}

resource "aws_route_table" "pv_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = var.pv_rt
  }
}

resource "aws_route_table_association" "pv01_assoc" {
  subnet_id      = aws_subnet.pv01.id
  route_table_id = aws_route_table.pv_rt.id
}

resource "aws_route_table_association" "pv02_assoc" {
  subnet_id      = aws_subnet.pv02.id
  route_table_id = aws_route_table.pv_rt.id
}


# ==========================================
#  Image & Roles
# ==========================================

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_iam_role" "instancerole" {
  name = "instanceRole"
}

resource "aws_iam_instance_profile" "ec2_role" {
  name = "ec2-instance-profile"
  role = data.aws_iam_role.instancerole.name
}


# ==========================================
# Security Groups
# ==========================================

resource "aws_security_group" "alb_sg" {
  name   = var.alb_sg
  vpc_id = aws_vpc.vpc.id

  ingress {
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
    Name = var.alb_sg
  }
}

resource "aws_security_group" "web_sg" {
  name   = var.web_sg
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.web_sg
  }
}

resource "aws_security_group" "app_sg" {
  name   = var.app_sg
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.app_sg
  }
}

resource "aws_security_group" "rds_rg" {
  name   = var.rds_rg
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.rds_rg
  }
}


# ==========================================
#  Application Load Balancer (Public)
# ==========================================

resource "aws_lb" "pb_alb" {
  name               = var.alb_name
  subnets            = [aws_subnet.pb01_subnet.id, aws_subnet.pb02_subnet.id]
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]

  tags = {
    Name = var.alb_name
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name     = var.alb_tg
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = var.alb_tg
  }
}

resource "aws_lb_listener" "alb_listner" {
  port              = 80
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.pb_alb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.web_ins.id
  port             = 80
}


# ==========================================
#              EC2
# ==========================================

resource "aws_instance" "web_ins" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.pv01.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_role.name

  depends_on = [aws_instance.app_ins]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y httpd 

    cat > /etc/httpd/conf.d/proxy.conf <<EOT
    <VirtualHost *:80> 
      ProxyPreserveHost On 
      ProxyPass / http://${aws_instance.app_ins.private_ip}:8080/
      ProxyPassReverse / http://${aws_instance.app_ins.private_ip}:8080/
    </VirtualHost>
    EOT

    systemctl start httpd
    systemctl enable httpd
  EOF
  )

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = var.web_ins
  }
}

resource "aws_instance" "app_ins" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.pv02.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_role.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y httpd

    mkdir -p /var/www/html

    cat > /var/www/html/index.html <<EOT
    <!DOCTYPE html>
    <html>
    <head>
        <title>Application EC2 Server</title>
    </head>
    <body>
        <h1>Application Status: Online</h1>
        <p>This is the backend application</p>
    </body>
    </html>
    EOT

    sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf
    systemctl enable httpd
    systemctl restart httpd
  EOF
  )

  tags = {
    Name = var.app_ins
  }
}


# ==========================================
# Database Tier (RDS)
# ==========================================

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = var.db_subnet_group
  subnet_ids = [aws_subnet.pv01.id, aws_subnet.pv02.id]
  tags = {
    Name = var.db_subnet_group
  }
}

resource "aws_db_instance" "rds" {
  identifier        = var.rds_identifier
  allocated_storage = 20

  engine         = "mysql"
  engine_version = "8.0"

  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  instance_class       = "db.t3.micro"

  username = var.db_username
  password = var.db_password
  db_name  = var.db_name

  vpc_security_group_ids = [aws_security_group.rds_rg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}