# Register the existing local public key with AWS when available.
# The private key remains on this computer.
locals {
  ssh_public_key_path   = pathexpand("~/.ssh/id_ed25519.pub")
  ssh_public_key_exists = fileexists(local.ssh_public_key_path)
}

resource "aws_key_pair" "admin" {
  for_each   = local.ssh_public_key_exists ? { admin = file(local.ssh_public_key_path) } : {}
  key_name   = "rt-helpdesk-admin"
  public_key = each.value
}

# Jenkins controller and build agent host.
module "ci_host" {
  source = "./modules/host"

  name              = "rt-helpdesk-ci-host"
  ami               = "ami-0c6ce2792061d6494"
  instance_type     = "t3.medium"
  subnet_id         = data.aws_subnet.public.id
  security_group_id = data.aws_security_group.ci.id
  key_name          = local.ssh_public_key_exists ? aws_key_pair.admin["admin"].key_name : null
}

# Kubernetes application and monitoring host.
module "app_host" {
  source = "./modules/host"

  name              = "rt-helpdesk-app-host"
  ami               = "ami-0c6ce2792061d6494"
  instance_type     = "t3.large"
  subnet_id         = data.aws_subnet.public.id
  security_group_id = data.aws_security_group.app.id
  key_name          = local.ssh_public_key_exists ? aws_key_pair.admin["admin"].key_name : null
  instance_profile  = data.aws_iam_instance_profile.app.name
}
