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
| Credential | None. You use your normal Clara login | A Clara API key with the `aws-onboarding` permissions |
| What you add | Nothing. Run this module, then paste the `role_arn` output into the wizard | `modules/registration` and the `nops-io/clara` provider |
| Best for | A first account, or when no API key is available | Pipelines and many accounts |

Both end in the same place: an integration in Clara that Clara verifies by assuming the role.

**UI-assisted.** Start the integration in Clara and choose Terraform. The wizard shows a configuration with your client id and ExternalId filled in. Apply it, run `terraform output -raw role_arn`, paste the value into the wizard, and verify.

**Headless.** Keep the key out of your files and set it in the environment:

```bash
export CLARA_API_KEY=...
```

```hcl
provider "clara" {}

data "clara_context" "this" {}

module "clara" {
  source    = "nops-io/clara-onboarding/aws"
  client_id = data.clara_context.this.client_id
  # ...
}

module "clara_registration" {
  source           = "nops-io/clara-onboarding/aws//modules/registration"
  payer_account_id = "<payer-account-id>"
  registration     = module.clara.registration
}
```

The registration module waits for Clara's verification and fails unless the integration becomes active. `terraform destroy` disconnects the integration in Clara. It does not delete anything in AWS. The full example is in `examples/headless-registration`.

## Requirements

- Terraform `>= 1.6.0`
- AWS provider `~> 6.0`, `random ~> 3.6`, `time ~> 0.12`
- Run in the payer (management) account. Child roles and Commitment Management also need CloudFormation StackSets trusted access for the organization.
- A second provider, `aws.sharesave`, configured for a dedicated child account. It is used only when `enable_commitment_management = true`, and the module refuses to deploy the ShareSave role into the payer account.
- A `us-east-1` provider, passed as `aws.us_east_1`. CUR and BCM data exports are only available in `us-east-1`.

## Usage

Savings Analysis, Minimum Platform:

```hcl
module "clara" {
  source  = "nops-io/clara-onboarding/aws"
  version = "~> 1.0"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
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
  version = "~> 1.0"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
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
  version = "~> 1.0"

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
| `cur_bucket_name` | CUR delivery bucket. Created by the module. Required. | — |
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
| `cur_bucket_name`, `cur_report_name`, `cur2_export_arn` | CUR resources, or `null`. |
| `child_role_name` | Savings Analysis child role deployed to member accounts, or `null`. |
| `commitment_central_role_arn` | Commitment Management central role, or `null`. |
| `commitment_sharesave_role_arn` | ShareSave role, or `null`. |
| `registration` | All registration values in one object. Sensitive. |

## Notes

- The module creates the CUR bucket. Existing buckets are not supported, because the bucket policy is a single document and would replace the one you have.
- The ShareSave role must be in a dedicated child account. The module refuses to deploy it into the payer.
- Commitment Management creates CloudFormation stacks, with the same template Clara's wizard uses. A stack name collision with an existing Clara stack fails the plan.
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
