provider "aws" {
  region = "il-central-1"

  default_tags {
    tags = {
      Project   = local.project
      ManagedBy = "terraform"
      Region    = "il-central-1"
    }
  }
}
