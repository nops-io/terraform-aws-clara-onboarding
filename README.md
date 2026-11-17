# Clara AWS onboarding

Terraform module that connects an AWS payer (management) account to Clara. It creates the IAM role, policies, and cost and usage reports that Clara needs, and exposes the values Clara needs to register the account.

Use one module for every AWS onboarding feature. Enable the features you want with variables.

## Features

| Feature | Variable | Creates |
|---|---|---|
| Savings Analysis | `enable_savings_analysis` (default `true`) | Integration role with a locked trust, Minimum or Full Platform policies, CUR bucket, Legacy CUR, optional CUR 2.0 export |
| Child roles | `enable_child_roles` (default `false`) | Read role in every member account of your organization, deployed with a service-managed StackSet. Requires Savings Analysis. |

Commitment Management will be added as another feature. It is not available yet.

## Requirements

- Terraform `>= 1.6.0`
- AWS provider `~> 6.0`, `random ~> 3.6`, `time ~> 0.12`
- Run in the payer (management) account. Child roles also need CloudFormation StackSets trusted access for the organization.
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

Full examples are in `examples/`.

## Inputs

| Name | Description | Default |
|---|---|---|
| `enable_savings_analysis` | Deploy the Savings Analysis integration. | `true` |
| `enable_child_roles` | Deploy the child role StackSet. Requires Savings Analysis. | `false` |
| `client_id` | Clara client id. Required. | — |
| `data_connector_principal_arn` | Clara data connector role. | Clara production role |
| `external_id` | ExternalId for the trust. Sensitive. Generated when null. | `null` |
| `permission_mode` | `minimal` (Savings Analysis) or `full` (Inform & Operate). | `minimal` |
| `cur_bucket_name` | CUR delivery bucket. Created by the module. Required. | — |
| `create_legacy_cur` | Create the Legacy CUR. | `true` |
| `create_cur2` | Create the CUR 2.0 export. | `false` |
| `organizational_unit_ids` | Root or OU ids for the child role StackSet. | `[]` |
| `tags` | Tags for supported resources. | `{}` |

## Outputs

| Name | Description |
|---|---|
| `role_arn`, `role_name` | Integration role. |
| `external_id` | ExternalId. Sensitive. |
| `cur_bucket_name`, `cur_report_name`, `cur2_export_arn` | CUR resources, or `null`. |
| `child_role_name` | Child role deployed to member accounts, or `null`. |
| `registration` | All registration values in one object. Sensitive. |

## Notes

- The module creates the CUR bucket. Existing buckets are not supported, because the bucket policy is a single document and would replace the one you have.
- IAM names are account-wide. An account that already has the Clara CloudFormation stacks needs those resources imported before this module can run.
- The ExternalId is a shared secret for the trust. Changing it breaks the trust until Clara is updated.
- Registering the account with Clara is a separate step, done with the Clara provider.

## Examples

- `examples/savings-analysis-minimum`
- `examples/savings-analysis-full`
- `examples/with-child-roles`

Each example validates as is. Replace the placeholder values before you apply.
