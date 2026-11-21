# Amazon ECR Image Evidence

## Verified image

The following image was verified directly against Amazon ECR in
`il-central-1`.

| Field | Value |
|---|---|
| AWS account | `391924456595` |
| Region | `il-central-1` |
| Repository | `rt-helpdesk` |
| Image tag | `94f3548` |
| Image digest | `sha256:3e7f8e870f0954dfc3bb13116bcceb211acbfe68cd7a45c56e1d5195c83c4f14` |
| Pushed at | `2026-11-19T02:29:03.353000+02:00` |
| Image size | `53,995,068` bytes |
| Manifest media type | `application/vnd.oci.image.index.v1+json` |

Verified using `aws ecr describe-images`.

## Associated source commit

- Commit: `94f3548ed1763ba69c9e73a1d8d029a21b3350db`
- Date: `2026-11-17T18:23:33+02:00`
- Subject: `M1: harden runtime image — drop requirements.txt from /app (#3)`

The tag and commit association is documented here; it does not independently prove that the image was built from that exact checkout.

## CloudTrail publication evidence

A CloudTrail lookup identified a successful ECR `PutImage` event:

- Event ID: `adb02de2-15f2-4eb3-bd35-2a46e51c0ecf`
- Event time: `2026-11-19T00:29:03Z`
- Repository: `rt-helpdesk`
- Image tag: `94f3548`
- AWS principal: `arn:aws:iam::391924456595:user/Admin`
- Error code: none

The event's `sourceIPAddress` and `userAgent` values are `ecr.amazonaws.com`. They do not identify the originating computer or build system.

## Evidence scope and limitations

This evidence establishes that:

1. The image tag was present in ECR when queried.
2. ECR reported the digest, size, media type, and push timestamp above.
3. CloudTrail recorded a successful `PutImage` operation associated with the tag under IAM user `Admin`.
4. The tag matches the short identifier of the documented Git commit.

This evidence does **not** establish that:

- Jenkins performed the image publication.
- A particular machine or CI job built the image.
- The image was deployed to Kubernetes or an AWS host.
- A live application deployment was verified.

GitHub Actions CI validation and ECR image publication are separate activities. A successful CI run is not proof of an ECR push or deployment.
