# Milestone 2 will populate VPC, subnets, EC2, security groups and S3.
# This scaffold lets CI exercise `terraform fmt -check` and `terraform validate`
# (the terraform job skips itself when no .tf files exist).
locals {
  project = "rt-helpdesk"
}
