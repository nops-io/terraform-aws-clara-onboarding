# Changelog

## 0.1.0 (Unreleased)

FEATURES:

- Savings Analysis at the Minimum or Full Platform permission level: the integration role, its IAM policies, and the CUR bucket,
  Legacy CUR export and optional CUR 2.0 export in `us-east-1`. An existing CUR bucket can be used instead of a new one.
- Optional Savings Analysis child roles in member accounts, deployed with CloudFormation StackSets.
- Optional Commitment Management roles, including the ShareSave role in a dedicated child account.
- `modules/registration`: registers the payer account with Clara through the `nops-io/clara` provider.
