# Registration

Registers the payer account with Clara once the root module has created the AWS resources. It uses the
[`nops-io/clara`](https://registry.terraform.io/providers/nops-io/clara/latest) provider and a Clara API key that has only the
`aws-onboarding:create` permission.

Set the key in the environment so it never appears in your files:

```bash
export CLARA_API_KEY=<onboarding key>
```

Create the key in the Clara AWS setup wizard (**Terraform, full setup**), or under **Settings → Security → API Keys** with only
`aws-onboarding:create` selected.

## Usage

```hcl
provider "clara" {}

module "clara_registration" {
  source  = "nops-io/clara-onboarding/aws//modules/registration"
  version = "~> 0.1"

  payer_account_id = "<payer-account-id>"
  registration     = module.clara.registration
}
```

The full example is in [`examples/headless-registration`](../../examples/headless-registration).

## Create-only

The key can register an account and nothing else, so:

- **Plan and refresh** make no requests to Clara.
- **A changed input is refused** at plan time. Change the integration in Clara instead.
- **Destroy leaves the integration in Clara.** Disconnect it there if it should go.
- **One integration per payer account.** If the account already has one, registration fails with a message saying so.
- **A failed access check is a warning.** The integration already exists, so the apply succeeds. Check `verification_state`, then fix the
  failed checks and verify again from Clara.

## Requirements

| Name | Version |
| --- | --- |
| terraform | >= 1.6.0 |
| nops-io/clara | ~> 0.1 |

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| `payer_account_id` | 12-digit payer (management) account id that the root module was applied in. | n/a |
| `registration` | The `registration` output of the root module. Extra attributes in that output are ignored. | n/a |
| `name` | Name shown in Clara. When unset, Clara uses `AWS Account <payer account id>`. | `null` |

## Outputs

| Name | Description |
| --- | --- |
| `integration_id` | Clara integration id. |
| `status` | Integration status when it was created: `active`, `validating` or `awaiting_customer_setup`. Not refreshed. |
| `verification_state` | Result of Clara's access check at creation: `verified`, `partial`, `failed` or `unavailable`. Not refreshed. |
| `failed_checks` | Permission checks that failed at creation. Empty when everything passed. |
