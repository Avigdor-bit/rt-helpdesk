# GitHub Actions CI Evidence

## Latest successful main run

- Repository: Avigdor-bit/rt-helpdesk
- Branch: main
- Commit: 318d3747752d84703c34a73ab86061d3a0ff8530
- Run ID: 44917156684
- Workflow: App CI
- Result: success

GitHub run:
https://github.com/Avigdor-bit/rt-helpdesk/actions/runs/44917156684

## Terraform validation fix

- Commit: 22fea59754ca2f15f7cabb3a8bb046529495cb08
- Run ID: 44916454285
- Result: success

The Terraform configuration passed formatting and validation after
making SSH key-pair creation conditional on the presence of a local
public key.

## Verified CI checks

1. Terraform formatting
2. Terraform initialization and validation
3. Python dependency installation
4. Pytest execution
5. Runtime Docker image build
6. Test artifact upload

## Development history

- Run #11 (`c580bda`): failed.
- Run #12 (`7c6e4a4`): failed.
- Run #13 (`22fea59`): successful.
- Run #14 (`318d374`): successful.

The history retains earlier failures rather than presenting only
successful runs. The latest two main-branch runs completed successfully.

## Scope and limitations

This workflow validates and tests the project and builds the runtime
Docker image. It does not publish the image to ECR, apply Terraform,
or deploy the application to Kubernetes or an AWS host.

A successful CI run is not evidence of a live infrastructure deployment.
