# Register the existing local public key with AWS.
# The private key remains on this computer.
resource "aws_key_pair" "admin" {
  key_name   = "rt-helpdesk-admin"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}

# Jenkins controller and build agent host.
module "ci_host" {
  source = "./modules/host"

  name              = "rt-helpdesk-ci-host"
  ami               = "ami-0c6ce2792061d6494"
  instance_type     = "t3.medium"
  subnet_id         = data.aws_subnet.public.id
  security_group_id = data.aws_security_group.ci.id
  key_name          = aws_key_pair.admin.key_name
}

# Kubernetes application and monitoring host.
module "app_host" {
  source = "./modules/host"

  name              = "rt-helpdesk-app-host"
  ami               = "ami-0c6ce2792061d6494"
  instance_type     = "t3.large"
  subnet_id         = data.aws_subnet.public.id
  security_group_id = data.aws_security_group.app.id
  key_name          = aws_key_pair.admin.key_name
  instance_profile  = data.aws_iam_instance_profile.app.name
}
