# Reuse the existing RT Helpdesk network.
# These data sources look up AWS resources; they do not create them.

data "aws_vpc" "project" {
  id = "vpc-0a7e9b9c4c5cd7221"
}

data "aws_subnet" "public" {
  id = "subnet-0e51e5a82b0ffc9e3"
}

data "aws_security_group" "ci" {
  id = "sg-0307081a6c0b5bcfc"
}

data "aws_security_group" "app" {
  id = "sg-0a9e213e20cf3f233"
}

# Reuse the existing application backup instance profile.
data "aws_iam_instance_profile" "app" {
  name = "rt-helpdesk-app-host"
}
