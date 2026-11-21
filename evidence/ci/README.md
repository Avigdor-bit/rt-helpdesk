# GitHub Actions CI Evidence

## Successful run

- Repository: Avigdor-bit/rt-helpdesk
- Branch: main
- Commit: 22fea59754ca2f15f7cabb3a8bb046529495cb08
- Run ID: 44916454285
- Workflow: App CI
- Result: success

## Verified jobs

1. Terraform fmt/validate — success
2. PostgreSQL and API tests — success

## Verified checks

- Terraform formatting
- Terraform initialization and validation
- Python dependency installation
- Pytest execution
- Runtime Docker image build
- Test artifact upload

GitHub run:
https://github.com/Avigdor-bit/rt-helpdesk/actions/runs/44916454285

Note: This evidence confirms CI checks only. It does not establish
that Terraform changes were applied to live AWS infrastructure.
