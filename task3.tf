provider "aws" {
  region  = "ap-south-1"
  profile = "Mansi-IAM"
}

#Keypair
resource "tls_private_key" "key_form" {
  algorithm = "RSA"
}

resource "aws_key_pair" "task_key" {
  key_name   = "Myterakey"
  public_key = tls_private_key.key_form.public_key_openssh
}


#Create VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
tags = {
    Name = "myvpc"
  }
}

#create first subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "publicsubnet"
  }
}

#create second subnet 
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  
  tags = {
    Name = "privatesubnet"
  }
}

#create internet gateway
resource "aws_internet_gateway" "mygw" {
  depends_on = [aws_vpc.myvpc,aws_subnet.public,aws_subnet.private]
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "mygw"
  }
}

#create a route table 
resource "aws_route_table" "myrtable" {
   depends_on = [aws_internet_gateway.mygw,]
  
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mygw.id
  }
  tags = {
    Name = "Myrtable"
  }
}

#create association 
resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.myrtable.id
}

#security group for wordpress
resource "aws_security_group" "mywp-sg" {
  depends_on = [aws_vpc.myvpc]
  name        = "mywp-sg"
  description = "Allow http ssh mysqlport"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow mysql port"
    from_port   = 3306
    to_port     = 3306
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
    Name = "mywp-sg"
  }
}

#Security group for MYSQL
 resource "aws_security_group" "mysql-sg" {
   depends_on = [aws_vpc.myvpc]
  name        = "mysql-sg"
  description = "Allow mysqlport"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    description = "allow mysql port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.mywp-sg.id ]
  }
 
 
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_sg"
  }
}

#launch wordpress 
resource "aws_instance" "Wordpress" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [ aws_security_group.mywp-sg.id ] 
  #associate_public_ip_address = true
  key_name = "Myterakey" 

  tags = {
    Name = "Wordpress"
  }
}


#launch Mysql
resource "aws_instance" "mysql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private.id
  vpc_security_group_ids = [ aws_security_group.mysql-sg.id ] 
  #associate_public_ip_address = true
  key_name = "Myterakey" 

  tags = {
    Name = "mysql"
  }
}



resource "null_resource" "save_key_pair"  {
	provisioner "local-exec" {
	    command = "echo  '${tls_private_key.key_form.private_key_pem}' > key.pem"
  	}
}


