terraform {
  backend "s3" {
    bucket       = "rt-helpdesk-tfstate-391924456595-ilc1"
    key          = "rt-helpdesk/infrastructure.tfstate"
    region       = "il-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
