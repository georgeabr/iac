# Configure the AWS Provider 
# Replace "eu-west-2" with your desired region
# Replace "aws-sa-2" with your AWS CLI profile name

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0" # Use a version compatible with your code
    }
  }

  # Configure the S3 backend for state storage
  backend "s3" {
    bucket = "terraform-state-git" # <<-- REPLACE with your S3 bucket name
    key    = "tf-state/terraform.tfstate" # <<-- REPLACE with a unique path for this state file
    region = "eu-west-2" # <<-- REPLACE with your AWS region

    # Uncomment the line below and replace with your DynamoDB table name for state locking (Recommended)
    # dynamodb_table = "your-terraform-lock-table"

    # Optional: Enable server-side encryption for the state file
    # encrypt = true
  }
}

provider "aws" {
  region  = "eu-west-2"
  # profile = "aws-sa-2" - not needed for Github actions, we will use secrets
}

# Define variables for user-specific values
variable "key_pair_name" {
  description = "The name of the SSH key pair to use for the EC2 instances."
  type        = string
  default     = "my-aws2-keypair1" # Updated key_pair_name
}

variable "ami_id" {
  description = "The AMI ID for the Linux instances."
  type        = string
  default     = "ami-0306865c645d1899c" # Updated ami_id
}

# --- VPC 1 and associated resources ---

# Create VPC 1
resource "aws_vpc" "vpc1" {
  cidr_block = "10.1.0.0/16" # Replace with your desired CIDR block
  tags = {
    Name = "MyVPC1-Terraform"
  }
}

# Create Subnet 1 in VPC 1
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.1.1.0/24" # Replace with your desired CIDR block within VPC1
  availability_zone       = "eu-west-2a" # Corrected AZ specification
  map_public_ip_on_launch = true # Automatically assign public IPs to instances in this subnet

  tags = {
    Name = "MySubnet1-Terraform"
  }
}

# Create Internet Gateway for VPC 1
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "MyVPC1-IGW-Terraform"
  }
}

# Create Route Table for VPC 1
resource "aws_route_table" "rt1" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "MyVPC1-RT-Terraform"
  }
}

# Create default route to Internet Gateway in Route Table 1
resource "aws_route" "default_route1" {
  route_table_id         = aws_route_table.rt1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw1.id
  # Ensure this route is created before associating the route table
  depends_on = [aws_internet_gateway.igw1]
}

# Associate Route Table 1 with Subnet 1
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt1.id
}

# Create Security Group for VPC 1
resource "aws_security_group" "sg1" {
  name        = "my-vpc1-sg-terraform"
  description = "Allow SSH and Ping access for VPC1"
  vpc_id      = aws_vpc.vpc1.id

  # Ingress rule for SSH (port 22) from anywhere
  ingress {
    description = "SSH from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Allowing SSH from anywhere (0.0.0.0/0) is not recommended for production. Restrict to known IPs.
  }

  # Ingress rule for ICMP (Ping) from VPC2's CIDR block
  ingress {
    description = "Ping from VPC2"
    from_port   = -1 # -1 indicates all ICMP types and codes
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc2.cidr_block] # Allow ping from VPC2's CIDR
  }

  # Egress rule (allow all outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MyVPC1-SG-Terraform"
  }
}

# Create EC2 Instance 1 in Subnet 1
resource "aws_instance" "vm1" {
  ami           = var.ami_id
  instance_type = "t2.micro" # Or your desired instance type
  subnet_id     = aws_subnet.subnet1.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.sg1.id] # Associate the security group

  tags = {
    Name = "LinuxVM1-VPC1-Terraform"
  }
}

# --- VPC 2 and associated resources ---

# Create VPC 2
resource "aws_vpc" "vpc2" {
  cidr_block = "10.2.0.0/16" # Replace with your desired CIDR block (must not overlap with VPC1)
  tags = {
    Name = "MyVPC2-Terraform"
  }
}

# Create Subnet 2 in VPC 2
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.vpc2.id
  cidr_block              = "10.2.1.0/24" # Replace with your desired CIDR block within VPC2
  availability_zone       = "eu-west-2c" # Corrected AZ specification
  map_public_ip_on_launch = true # Automatically assign public IPs to instances in this subnet

  tags = {
    Name = "MySubnet2-Terraform"
  }
}

# Create Internet Gateway for VPC 2
resource "aws_internet_gateway" "igw2" {
  vpc_id = aws_vpc.vpc2.id
  tags = {
    Name = "MyVPC2-IGW-Terraform"
  }
}

# Create Route Table for VPC 2
resource "aws_route_table" "rt2" {
  vpc_id = aws_vpc.vpc2.id
  tags = {
    Name = "MyVPC2-RT-Terraform"
  }
}

# Create default route to Internet Gateway in Route Table 2
resource "aws_route" "default_route2" {
  route_table_id         = aws_route_table.rt2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw2.id
   # Ensure this route is created before associating the route table
  depends_on = [aws_internet_gateway.igw2]
}

# Associate Route Table 2 with Subnet 2
resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt2.id
}

# Create Security Group for VPC 2
resource "aws_security_group" "sg2" {
  name        = "my-vpc2-sg-terraform"
  description = "Allow SSH and Ping access for VPC2"
  vpc_id      = aws_vpc.vpc2.id

  # Ingress rule for SSH (port 22) from anywhere
  ingress {
    description = "SSH from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Allowing SSH from anywhere (0.0.0.0/0) is not recommended for production. Restrict to known IPs.
  }

  # Ingress rule for ICMP (Ping) from VPC1's CIDR block
  ingress {
    description = "Ping from VPC1"
    from_port   = -1 # -1 indicates all ICMP types and codes
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc1.cidr_block] # Allow ping from VPC1's CIDR
  }

  # Egress rule (allow all outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MyVPC2-SG-Terraform"
  }
}

# Create EC2 Instance 2 in Subnet 2
resource "aws_instance" "vm2" {
  ami           = var.ami_id
  instance_type = "t2.micro" # Or your desired instance type
  subnet_id     = aws_subnet.subnet2.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.sg2.id] # Associate the security group

  tags = {
    Name = "LinuxVM2-VPC2-Terraform"
  }
}

# --- VPC Peering Configuration ---

# Request and auto-accept a VPC peering connection from VPC1 to VPC2
resource "aws_vpc_peering_connection" "vpc_peering" {
  peer_vpc_id   = aws_vpc.vpc2.id
  vpc_id        = aws_vpc.vpc1.id
  auto_accept   = true # Set to true to auto-accept within the same account

  tags = {
    Name = "vpc1-to-vpc2-peering"
  }
}

# Add a route in VPC1's route table to send traffic for VPC2's CIDR block through the peering connection
resource "aws_route" "vpc1_to_vpc2_route" {
  route_table_id            = aws_route_table.rt1.id
  destination_cidr_block    = aws_vpc.vpc2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id # Reference the peering connection directly
  # Ensure the peering connection is active before adding the route
  depends_on = [aws_vpc_peering_connection.vpc_peering]
}

# Add a route in VPC2's route table to send traffic for VPC1's CIDR block through the peering connection
resource "aws_route" "vpc2_to_vpc1_route" {
  route_table_id            = aws_route_table.rt2.id
  destination_cidr_block    = aws_vpc.vpc1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id # Reference the peering connection directly
   # Ensure the peering connection is active before adding the route
  depends_on = [aws_vpc_peering_connection.vpc_peering]
}


# Output the public IPs of the instances
output "vm1_public_ip" {
  description = "Public IP address of VM 1"
  value       = aws_instance.vm1.public_ip
}

output "vm2_public_ip" {
  description = "Public IP address of VM 2"
  value       = aws_instance.vm2.public_ip
}

# Output the private IPs of the instances (for pinging within VPCs)
output "vm1_private_ip" {
  description = "Private IP address of VM 1"
  value       = aws_instance.vm1.private_ip
}

output "vm2_private_ip" {
  description = "Private IP address of VM 2"
  value       = aws_instance.vm2.private_ip
}

