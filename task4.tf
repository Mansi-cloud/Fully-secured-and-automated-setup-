provider "aws" {
  region = "ap-south-1"
  profile="Mansi-IAM"
}


# To create a key 

resource "tls_private_key" "Myterakey" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "task_key" {
  key_name   = "Myterakey"
  public_key = tls_private_key.Myterakey.public_key_openssh
  
  depends_on = [ tls_private_key.Myterakey ]
}

resource "local_file" "key-file" {
  content  = tls_private_key.Myterakey.private_key_pem
  filename = "Myterakey.pem"
  file_permission = 0400

  depends_on = [
    tls_private_key.Myterakey
  ]
}




# To create a custom VPC
resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "myvpc"
  }
}


# creating the security group fop allowing 80,22 inbound rules
resource "aws_security_group" "wp-sg" {
  name        = "wp_sg"
  description = "Allows SSH and HTTP"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
 
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    description = "allow ICMP"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wp-sg"
  }
}




#creating the security group fop allowing 3306 inbound rules

resource "aws_security_group" "mysql-sg" {
  name        = "mysql_sec_grp"
  description = "Allows MYSQL"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "allow ICMP"
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_groups = [aws_security_group.wp-sg.id]
  }

  ingress {
    description = "allow MySQL"
    from_port = 0
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.wp-sg.id]
  }


  egress {
  description = "allow ICMP"
  from_port = 0
  to_port=0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql-sg"
  }
}




# To create one subnet for private and public

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_subnet" "private" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]

    tags = {
      Name = "PrivateSubnet"
    }
}




# To create one Internet gateway in cutom created VPC

resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myigw"
  }
}


# creating the EIP for NAT Gateway


resource "aws_eip" "myng" {
	vpc = true

	depends_on = [ aws_internet_gateway.myigw ]
}


# Creating the NAT Gateway

resource "aws_nat_gateway" "mynatgw" {
	allocation_id = aws_eip.myng.id
	subnet_id = aws_subnet.public.id

	depends_on = [ aws_internet_gateway.myigw ]

	tags = {
		Name = "mynatgw"
	}
}


# To create the route table to have public instance to go to public world via Internet gateway

resource "aws_route_table" "publicroute" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "publicroute"
  }
}

# To associate the route table with the subnet created for public access

resource "aws_route_table_association" "publicassoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.publicroute.id
}




#To create the route table for private instance to go to public world via NAT
resource "aws_route_table" "privateroute" {
	vpc_id = aws_vpc.myvpc.id

	route {
		cidr_block = "0.0.0.0/0"
		nat_gateway_id = aws_nat_gateway.mynatgw.id
	}

	tags = {
		Name = "privateroute"
	}
}
#To associate the route table with the private subnet for public access
resource "aws_route_table_association" "privateassoc" {
	subnet_id = aws_subnet.private.id
	route_table_id = aws_route_table.privateroute.id
}


# Create a instance with wordpress for public access
resource "aws_instance" "Mywordpress" {
    ami           = "ami-7e257211"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    subnet_id = aws_subnet.public.id
    vpc_security_group_ids = [aws_security_group.wp-sg.id]
    key_name = aws_key_pair.task_key.key_name

    tags = {
        Name = "MYwordpress"
    }

    depends_on = [ tls_private_key.Myterakey, aws_vpc.myvpc, aws_security_group.wp-sg, aws_security_group.mysql-sg, aws_subnet.public, aws_subnet.private, aws_internet_gateway.myigw] 

}
  


# Create a instance with wordpress for private access but only allowed by wordpress in the private network & not for any
resource "aws_instance" "Mymysql" {
	ami =  "ami-08706cb5f68222d09"
	instance_type = "t2.micro"
	key_name = aws_key_pair.task_key.key_name
    vpc_security_group_ids = [aws_security_group.mysql-sg.id]
    subnet_id = aws_subnet.private.id

    tags = {
        Name = "MYmysql"
    }

    depends_on = [ tls_private_key.Myterakey, aws_vpc.myvpc, aws_security_group.wp-sg, aws_security_group.mysql-sg, aws_subnet.public, aws_subnet.private, aws_internet_gateway.myigw] 
}

#Take output of Wordpress and MySQL DB instances:


output "wordpress-publicip" {
  value = aws_instance.Mywordpress.public_ip
}



output "mysqldb-privateip" {
  value = aws_instance.Mymysql.private_ip
}

