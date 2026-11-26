# Clara AWS onboarding

Terraform module that connects an AWS payer (management) account to Clara. It creates the IAM role, policies, and cost and usage reports that Clara needs, and exposes the values Clara needs to register the account.

Use one module for every AWS onboarding feature. Enable the features you want with variables.

## Features

| Feature | Variable | Creates |
|---|---|---|
| Savings Analysis | `enable_savings_analysis` (default `true`) | Integration role with a locked trust, Minimum or Full Platform policies, CUR bucket, Legacy CUR, optional CUR 2.0 export |
| Child roles | `enable_child_roles` (default `false`) | Read role in every member account of your organization, deployed with a service-managed StackSet. Requires Savings Analysis. |
| Commitment Management | `enable_commitment_management` (default `false`) | Central role, payer read role, child read roles (StackSet) and the ShareSave role in a dedicated child account. Requires Savings Analysis. |

Full Platform is not a separate feature. It is `permission_mode = "full"` on Savings Analysis.

## Two ways to connect the account to Clara

The module creates the AWS side. Then the account has to be registered with Clara. Choose one:

| | UI-assisted | Headless |
|---|---|---|
| Who registers the account | You, in Clara's setup wizard | Terraform, through the Clara API |
| Credential | None. You use your normal Clara login | A Clara API key with only the `aws-onboarding:create` permission |
| What you add | Nothing. Run this module, then paste the `role_arn` output into the wizard | `modules/registration` and the `nops-io/clara` provider |
| Best for | A first account, or when no API key is available | Pipelines and many accounts |
| After it is registered | You manage the integration in Clara | Still in Clara. The key can only create, so changes and disconnects happen there |

Both end in the same place: an integration in Clara that Clara verifies by assuming the role.

**UI-assisted.** Start the integration in Clara and choose Terraform. The wizard shows a configuration with your client id and ExternalId filled in. Apply it, run `terraform output -raw role_arn`, paste the value into the wizard, and verify.

**Headless.** Keep the key out of your files and set it in the environment:

```bash
export CLARA_API_KEY=...
```

Create the key in Clara under **Settings → Security → API Keys** and select only `aws-onboarding:create`. That permission registers a new account and nothing else.

```hcl
provider "clara" {}

module "clara" {
  source  = "nops-io/clara-onboarding/aws"
  version = "~> 0.1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws # required, but used only when enable_commitment_management = true
  }

  client_id = "<your Clara client id>" # shown in the configuration the setup wizard generates
  # ...
}

module "clara_registration" {
  source           = "nops-io/clara-onboarding/aws//modules/registration"
  version          = "~> 0.1"
  payer_account_id = "<payer-account-id>"
  registration     = module.clara.registration
}
```

The registration module is **create-only**, because its key is. Clara checks access when the integration is created and the module reports `verification_state`. A failed check is a warning, not an error: the integration already exists, and a tainted resource could not be recreated. Plan makes no request to Clara, a changed registration is refused at plan time, and `terraform destroy` leaves the integration in Clara. Change or disconnect it there. If the account already has an integration, registration fails with a message saying so. The full example is in `examples/headless-registration`.

## Duplicates and re-runs

The module creates resources with fixed names in the payer account: the role `nops-integration-role-<client_id>`, the IAM policies `nOpsBucketPolicy`, `nOpsMinimumPlatformPermissions` and so on, the CUR report `nops_cur_<client_id>_hourly`, and the Commitment Management stacks and roles. Only one deployment can own those names in an account.

- **Re-running the same configuration** is safe. The state already holds the resources, so `terraform apply` changes nothing.
- **Deploying again in an account that already has them** (from this module, from Clara's CloudFormation stack, or from a second Terraform state) fails in AWS with `EntityAlreadyExists`. The module does not adopt or overwrite. Nothing is registered with Clara in that case.
- **Losing the state** means the next apply fails the same way. Import the existing resources into the new state (`terraform import`), or delete them, before applying.
- **A failed apply** can leave some resources created. They are in the state, so `terraform destroy` removes them.
- **Clara refuses a second integration** for the same payer account, even if the AWS resources are fine. The headless provider cannot adopt one. Remove the old integration in Clara first.

Use one of the onboarding paths per payer account: the CloudFormation wizard, this module, or the headless registration. Not two of them.

## Requirements

- Terraform `>= 1.6.0`
- AWS provider `~> 6.0`, `random ~> 3.6`, `time ~> 0.12`
- Run in the payer (management) account. Child roles and Commitment Management also need CloudFormation StackSets trusted access for the organization.
- A second provider, `aws.sharesave`, configured for a dedicated child account. It is used only when `enable_commitment_management = true`, and the module refuses to deploy the ShareSave role into the payer account.
- A `us-east-1` provider, passed as `aws.us_east_1`. CUR and BCM data exports are only available in `us-east-1`.
- Cost Explorer enabled in the payer account, and the root user must allow IAM access to billing information. Without both, Clara's `ce:` checks fail with "User not enabled for cost explorer access". The module cannot set either.

## Usage

Savings Analysis, Minimum Platform:

```hcl
module "clara" {
  source  = "nops-io/clara-onboarding/aws"
  version = "~> 0.1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws # required, but used only when enable_commitment_management = true
  }

  client_id       = "<clara-client-id>"
  cur_bucket_name = "<globally-unique-bucket>"
  permission_mode = "minimal"
}
```

Savings Analysis, Full Platform, with child roles:

```hcl
module "clara" {
  source  = "nops-io/clara-onboarding/aws"
  version = "~> 0.1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws # required, but used only when enable_commitment_management = true
  }

  client_id               = "<clara-client-id>"
  cur_bucket_name         = "<globally-unique-bucket>"
  permission_mode         = "full"
  create_cur2             = true
  enable_child_roles      = true
  organizational_unit_ids = ["<organization-root-id>"]
}
```

Savings Analysis with Commitment Management:

```hcl
provider "aws" {
  alias  = "sharesave"
  region = "us-east-1"
  assume_role {
    role_arn = "<role in the dedicated child account>"
  }
}

module "clara" {
  source  = "nops-io/clara-onboarding/aws"
  version = "~> 0.1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  client_id                    = "<clara-client-id>"
  cur_bucket_name              = "<globally-unique-bucket>"
  permission_mode              = "full"
  enable_commitment_management = true
  organizational_unit_ids      = ["<organization-root-id>"]
}
```

Full examples are in `examples/`.

## Inputs

| Name | Description | Default |
|---|---|---|
| `enable_savings_analysis` | Deploy the Savings Analysis integration. | `true` |
| `enable_child_roles` | Deploy the child role StackSet. Requires Savings Analysis. | `false` |
| `enable_commitment_management` | Deploy Commitment Management. Requires Savings Analysis and `aws.sharesave`. | `false` |
| `commitment_external_id` | ExternalId for the Commitment Management central role. Sensitive. Generated when null. | `null` |
| `sharesave_external_id` | ExternalId for the ShareSave role. Sensitive. Generated when null. | `null` |
| `cm_bridge_principal_arn` | Clara role that assumes the central role. | Clara production role |
| `sharesave_bridge_principal_arn` | Clara role that assumes the ShareSave role. | Clara production role |
| `client_id` | Clara client id. Required. | — |
| `data_connector_principal_arn` | Clara data connector role. | Clara production role |
| `external_id` | ExternalId for the trust. Sensitive. Generated when null. | `null` |
| `permission_mode` | `minimal` (Savings Analysis) or `full` (Inform & Operate). | `minimal` |
| `cur_bucket_name` | CUR delivery bucket. Required. Created by the module unless `create_cur_bucket = false`. | — |
| `create_cur_bucket` | `true` creates the bucket and its delivery policy. `false` uses a bucket you already own in us-east-1: the module writes nothing to it, so its bucket policy must already allow `billingreports.amazonaws.com` and `bcm-data-exports.amazonaws.com`. | `true` |
| `sharesave_template` | Commitment Management ShareSave role. `dual` deploys the API role and the console role (Switch Role), as Clara's Commitment Management wizard does. `single` deploys the API role only. | `dual` |
| `console_access_account_id` | Account whose root may use the ShareSave console role. Used with `sharesave_template = dual`. | Clara's production account |
| `create_legacy_cur` | Create the Legacy CUR. | `true` |
| `create_cur2` | Create the CUR 2.0 export. | `false` |
| `cur_report_name` | Legacy CUR report name. Empty means `nops_cur_<client_id>_hourly`. | `""` |
| `cur_s3_prefix` | Legacy CUR S3 prefix. Match what you enter in Clara. | `nops-cur` |
| `cur2_export_name` | CUR 2.0 export name. Empty means `nops_cur2_<client_id>_hourly`. | `""` |
| `cur2_s3_prefix` | CUR 2.0 S3 prefix. | `nops-cur2` |
| `organizational_unit_ids` | Root or OU ids for the child role StackSets (Savings Analysis and Commitment Management). | `[]` |
| `tags` | Tags for supported resources. | `{}` |

## Outputs

| Name | Description |
|---|---|
| `role_arn`, `role_name` | Integration role. |
| `external_id` | ExternalId. Sensitive. |
| `permission_mode` | Permission level of the integration role: `minimal` or `full`. |
| `cur_bucket_name`, `cur_report_name`, `cur2_export_arn` | CUR resources, or `null`. |
| `child_role_name` | Savings Analysis child role deployed to member accounts, or `null`. |
| `commitment_central_role_arn` | Commitment Management central role, or `null`. |
| `commitment_sharesave_role_arn` | ShareSave role, or `null`. |
| `registration` | All registration values in one object. Sensitive. |

## Permissions

The policies are the same ones Clara's CloudFormation templates attach. Both levels are mostly read-only, but they include some
actions that change your account:

- **Minimum Platform:** `cur:PutReportDefinition`, `bcm-data-exports:CreateExport`, `bcm-data-exports:UpdateExport` (to manage
  the Clara CUR exports), `support:CreateCase`, and `sts:AssumeRole`.
- **Full Platform** adds, among others: `ec2:CreateSnapshot`, `ec2:CreateTags`, `ec2:DeleteVolume`, `rds:AddTagsToResource`,
  `cur:DeleteReportDefinition`, `ce:CreateAnomalyMonitor`, `ce:UpdateCostAllocationTagsStatus`, `events:CreateEventBus`,
  `organizations:InviteAccountToOrganization`, `servicequotas:RequestServiceQuotaIncrease`, `support:ResolveCase`, and
  `wellarchitected:*`. It also attaches the AWS-managed `ReadOnlyAccess` policy, plus deny policies that block reading data
  outside the CUR bucket.

Review `modules/savings-analysis/policies/` for the full documents, or see
[Permissions & Resources](https://help.nops.io/aws/permissions-and-resources) for what each level is used for.

## Notes

- The ShareSave role must be in a dedicated child account. The module refuses to deploy it into the payer.
- Commitment Management creates CloudFormation stacks with the same templates Clara's wizard uses. A stack name collision with an existing Clara stack fails the plan.
- An existing CUR bucket is never changed. A bucket policy is a single document, so writing one would replace the policy the customer already has. The module reads the bucket and fails the plan unless it is in us-east-1.
- Commitment Management deploys ShareSave into one dedicated account. Clara's wizard can also deploy it to several purchase accounts through a StackSet. The module does not do that yet.
- IAM names are account-wide. An account that already has the Clara CloudFormation stacks needs those resources imported before this module can run.
- The ExternalId is a shared secret for the trust. Changing it breaks the trust until Clara is updated.
- Registering the account with Clara is a separate step: the wizard (no key) or `modules/registration` (API key). See above.
- The CUR 2.0 export is always delivered to the same bucket as the Legacy CUR. A separate CUR 2.0 bucket is not supported.

## Examples

- `examples/savings-analysis-minimum`
- `examples/savings-analysis-full`
- `examples/with-child-roles`
- `examples/commitment-management`
- `examples/headless-registration` (needs the `nops-io/clara` provider)

Each example validates as is. Replace the placeholder values before you apply.
