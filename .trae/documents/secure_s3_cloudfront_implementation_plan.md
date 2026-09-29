# Secure S3 and CloudFront Website Implementation Plan

## Summary

Implement the static Kojo profile website from `website_deployed_s3/TERRAFORM_IMPLEMENTATION_GUIDE.md` using Terraform.

The initial deployment will use CloudFront's assigned `*.cloudfront.net` URL, which serves the site over HTTPS without requiring a custom domain, Route 53 hosted zone, or ACM certificate. The S3 origin will remain private and will be readable only by the intended CloudFront distribution through Origin Access Control (OAC).

Terraform will use a bootstrap-created S3 remote-state bucket with versioning, encryption, public-access blocks, and `use_lockfile = true`. The repository will have separate `dev`, `staging`, and `prod` root modules that reuse one shared `static_website` module. Only `dev` will be initialized, planned, and applied during the first deployment.

## Current State Analysis

- `website_deployed_s3/` currently contains only the task PDF and `TERRAFORM_IMPLEMENTATION_GUIDE.md`; no Terraform files or website assets exist yet.
- The guide directs the use of a `bootstrap/` state bucket, `modules/static_website/`, and environment roots in `environments/dev`, `environments/staging`, and `environments/prod`.
- The known AWS profile is `spomega`; the default workload region is `eu-central-1`.
- The PDF's IAM/MFA/budget task is already completed and is explicitly out of scope.
- The project will not create Route 53, ACM, WAF, Shield Advanced, or a custom domain in this iteration.

## Assumptions and Decisions

1. **Access URL:** Use the default CloudFront distribution hostname, exposed as `cloudfront_url`. This provides TLS/HTTPS automatically with no domain registration, DNS, or ACM setup.
2. **Origin model:** CloudFront uses the S3 REST regional endpoint (`bucket_regional_domain_name`), never the S3 website endpoint. The website endpoint is configured only to satisfy the learning objective and remains inaccessible because the bucket is private.
3. **OAC:** Use SigV4 OAC with `signing_behavior = "always"`. The bucket policy permits `s3:GetObject` only to `cloudfront.amazonaws.com`, conditioned on the exact distribution ARN.
4. **S3 security:** Enable bucket-owner-enforced object ownership, all public-access blocks, default server-side encryption, versioning, and an explicit deny for non-TLS S3 requests. No public-read statements or ACLs will be created.
5. **Environment strategy:** Create all three environment roots with unique state keys and bucket-name suffixes. Deploy only `dev`; `staging` and `prod` are ready for a later explicit deployment.
6. **State bootstrapping:** `bootstrap/` initially uses local state to create the backend bucket. It is intentionally excluded from ordinary environment destroys and uses `prevent_destroy`.
7. **Website:** Add a lightweight, responsive five-file professional profile for Kojo Mensah: `index.html`, `about.html`, `error.html`, `style.css`, and `logo.svg`. It will be uploaded as private S3 objects with accurate content types.
8. **Cost control:** Use `PriceClass_100` for the CloudFront distribution. No custom domain means no Route 53 hosted-zone cost in this iteration. Existing account budget monitoring remains the cost safety mechanism.
9. **Observability:** Enable CloudFront standard logging only if the account already has or can provide a dedicated encrypted, private logging bucket. The implementation will otherwise avoid creating a public or shared log destination. CloudTrail remains the control-plane audit record.

## Proposed Changes

### 1. Create Backend Bootstrap Configuration

Create `website_deployed_s3/bootstrap/`:

- `versions.tf`: Pin compatible Terraform and AWS provider versions.
- `providers.tf`: Use the `spomega` profile and default region variables.
- `variables.tf`: Define `aws_region`, `aws_profile`, `state_bucket_name`, and shared tags.
- `main.tf`:
  - Create the dedicated S3 state bucket.
  - Enable versioning.
  - Enable default server-side encryption.
  - Enable all S3 public-access blocks.
  - Enforce TLS using an S3 bucket policy.
  - Add `lifecycle { prevent_destroy = true }`.
- `outputs.tf`: Export the remote state bucket name and region.
- `terraform.tfvars.example`: Document the required globally unique state-bucket name without storing account-specific values.

Why: The S3 backend must already exist before environment Terraform roots can initialize with remote state.

### 2. Create Shared Static Website Module

Create `website_deployed_s3/modules/static_website/`:

- `versions.tf`: Terraform/AWS provider constraints appropriate for module consumers.
- `variables.tf`: Define project name, environment, region, optional log inputs, and shared tags. Do not include custom-domain inputs in the active interface.
- `main.tf`:
  - Derive a DNS-compliant, globally unique website bucket name from project, environment, account ID, and region.
  - Create and protect the S3 website bucket.
  - Enable S3 website configuration with `index.html` and `error.html`.
  - Upload the five private website assets with `aws_s3_object` and content types.
  - Create `aws_cloudfront_origin_access_control`.
  - Create an enabled `aws_cloudfront_distribution` with:
    - S3 regional REST origin and OAC.
    - `default_root_object = "index.html"`.
    - HTTPS redirect for viewers.
    - managed `CachingOptimized` cache policy.
    - managed `SecurityHeadersPolicy` response headers policy.
    - `PriceClass_100`.
    - default CloudFront certificate.
  - Create a bucket policy with a TLS-deny statement and a CloudFront-only `s3:GetObject` allow statement scoped with `AWS:SourceArn` to the distribution ARN.
- `outputs.tf`: Export `cloudfront_url`, distribution ID, distribution domain name, bucket name, bucket regional domain name, S3 website endpoint, and direct object URL for private-origin verification.

Why: The module creates the secure resource dependency chain: assets -> private S3 bucket -> OAC -> CloudFront distribution -> scoped S3 bucket policy.

### 3. Add Kojo's Website Assets

Create `website_deployed_s3/modules/static_website/site/`:

- `index.html`: A polished landing page for Kojo Mensah, Cloud and DevOps Engineer, with a concise professional headline and link to the about page.
- `about.html`: Bio, skills (Terraform, AWS, CI/CD, Linux, containers, monitoring), and experience-style sections.
- `error.html`: Branded helpful 404 page linking back to the landing page.
- `style.css`: Responsive, accessible visual system shared by all pages.
- `logo.svg`: Locally stored, simple Kojo monogram/logo; no external image dependencies.

Why: The PDF requires website files in the root of the S3 bucket; Terraform uploads these source assets as root-level private objects.

### 4. Create Environment Root Modules

Create `website_deployed_s3/environments/dev/`, `staging/`, and `prod/`, each with:

- `backend.tf`: S3 backend settings using a unique key:
  - `website/dev/terraform.tfstate`
  - `website/staging/terraform.tfstate`
  - `website/prod/terraform.tfstate`
  - `use_lockfile = true`
  - encrypted state
- `providers.tf`: AWS provider configured through variables for `spomega` and `eu-central-1`.
- `variables.tf`: Region, profile, environment, project name, state bucket name (backend configuration remains partial), and common tags.
- `main.tf`: Calls `../../modules/static_website` with its environment-specific values.
- `outputs.tf`: Re-exports the shared module's CloudFront URL, distribution ID, and bucket name.
- `terraform.tfvars.example`: Safe template with the appropriate environment name and a placeholder for values not committed to source control.

Why: Independent roots create strong separation between environments while sharing the same tested module.

### 5. Add Repository Hygiene

Create `website_deployed_s3/.gitignore` to exclude:

- `.terraform/`
- `.terraform.lock.hcl` only if the repository’s existing convention is to avoid committing provider locks; otherwise retain and commit it after initialization.
- `terraform.tfstate`
- `terraform.tfstate.*`
- `*.tfplan`
- real `terraform.tfvars`
- backend override files

Do not ignore `terraform.tfvars.example`, source website assets, module source, or the implementation guide.

### 6. Initialize and Validate

Run the following in order:

1. In `bootstrap/`: `terraform fmt -recursive`, `terraform init`, and `terraform validate`.
2. Run `terraform plan -out=tfplan` for bootstrap and present the plan for review before applying.
3. Apply bootstrap only after the plan is accepted; record the generated state bucket name.
4. In `environments/dev/`: add the actual backend bucket name using partial backend configuration, then run `terraform init -reconfigure`.
5. Run `terraform fmt -recursive`, `terraform validate`, and `terraform plan -out=tfplan` in `environments/dev/`.
6. Apply only the reviewed `dev` plan.

No apply will be run for staging or production during the first implementation.

## Verification and Acceptance Criteria

### Terraform Validation

- `terraform fmt -check -recursive` succeeds in `bootstrap/` and the environment roots.
- `terraform validate` succeeds in `bootstrap/` and `environments/dev/`.
- The dev plan creates the expected S3 website bucket, OAC, CloudFront distribution, site objects, and scoped S3 bucket policy.
- The plan contains no Route 53, ACM, public-read S3 policy, OAI, or custom-domain resources.

### Functional Verification

After CloudFront finishes deploying:

1. `terraform output -raw cloudfront_url` returns an `https://<distribution>.cloudfront.net` address.
2. Opening the CloudFront URL loads Kojo's `index.html` without including `/index.html`.
3. `https://<distribution>.cloudfront.net/about.html` loads successfully.
4. An HTTP request to the CloudFront hostname redirects to HTTPS.
5. A direct S3 object URL returns `AccessDenied`.
6. The S3 website endpoint returns `AccessDenied`.
7. S3 Block Public Access remains enabled and the bucket policy contains no broad public-read allow.
8. Browser developer tools show expected content types for HTML, CSS, and SVG.

### Security Verification

- The CloudFront origin uses `bucket_regional_domain_name`, not the website endpoint.
- OAC uses SigV4 signing and always signs origin requests.
- The CloudFront bucket-policy allow statement includes the distribution-specific `AWS:SourceArn`.
- The bucket enforces TLS for direct S3 requests.
- No static AWS credentials appear in Terraform configuration, state configuration, or committed variable files.

## Rollout and Cleanup

- Start with `dev`; wait for CloudFront deployment completion before functional tests.
- Promote the same module configuration to staging and production only through separate reviewed plans.
- Destroy an environment from its own root directory with `terraform destroy` when required.
- Do not destroy the backend bootstrap bucket until all environment state has been intentionally migrated or retired.

## Out of Scope for This Iteration

- Route 53 hosted zones, DNS delegation, custom aliases, and ACM certificates.
- WAF, Shield Advanced, and paid CloudFront security protections, following the PDF’s instruction not to enable those protections in the initial exercise.
- IAM/MFA/budget setup from PDF task 1.
- CI/CD automation and automated deployment pipelines.
