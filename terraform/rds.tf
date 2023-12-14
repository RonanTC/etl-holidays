resource "aws_vpc" "etl_hols_vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true

  tags = {
    Name = "etl-hols"
  }
}

resource "aws_subnet" "etl_hols_subnet_a" {
  vpc_id            = aws_vpc.etl_hols_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
}

resource "aws_subnet" "etl_hols_subnet_b" {
  vpc_id            = aws_vpc.etl_hols_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"
}

resource "aws_subnet" "etl_hols_subnet_c" {
  vpc_id            = aws_vpc.etl_hols_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2c"
}

resource "aws_db_subnet_group" "etl_hols_subnet_group" {
  name = "etl-hols-subnet-group"
  subnet_ids = [
    aws_subnet.etl_hols_subnet_a.id,
    aws_subnet.etl_hols_subnet_b.id,
    aws_subnet.etl_hols_subnet_c.id
  ]

  tags = {
    Name = "ETL-Holidays OLTP DB Subnet Group"
  }
}

resource "aws_security_group" "etl_hols_generator_sg" {
  name_prefix = "etl-hols-"
  vpc_id      = aws_vpc.etl_hols_vpc.id
}

resource "aws_vpc_security_group_egress_rule" "postgres_egress_rule" {
  security_group_id = aws_security_group.etl_hols_generator_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 5432
  ip_protocol = "tcp"
  to_port     = 5432
}

resource "aws_vpc_security_group_ingress_rule" "postgres_ingress_rule" {
  security_group_id = aws_security_group.etl_hols_generator_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 5432
  ip_protocol = "tcp"
  to_port     = 5432
}

resource "aws_vpc_security_group_ingress_rule" "secrets_ingress_rule" {
  security_group_id = aws_security_group.etl_hols_generator_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "secrets_egress_rule" {
  security_group_id = aws_security_group.etl_hols_generator_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_endpoint" "sm_endpoint" {
  vpc_id              = aws_vpc.etl_hols_vpc.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.etl_hols_generator_sg.id]
  private_dns_enabled = true
  subnet_ids = [
    aws_subnet.etl_hols_subnet_a.id,
    aws_subnet.etl_hols_subnet_b.id,
    aws_subnet.etl_hols_subnet_c.id
  ]
}

resource "aws_db_instance" "mock_oltp" {
  allocated_storage   = 20
  engine              = "postgres"
  db_name             = "etlhols"
  instance_class      = "db.t3.micro"
  username            = var.rds_oltp_admin_usr
  password            = var.rds_oltp_admin_pass
  skip_final_snapshot = true
  identifier_prefix   = "etl-hols-oltp-"

  vpc_security_group_ids = [aws_security_group.etl_hols_generator_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.etl_hols_subnet_group.name
}
