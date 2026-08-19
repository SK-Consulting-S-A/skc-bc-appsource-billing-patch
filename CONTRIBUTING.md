# Contributing

Thank you for helping improve the **Subscription Billing Community Patch**.
This repository is maintained by [SK Consulting S.A.](https://www.skc.lu).
Contributions are welcome from the community, and **every change lands through
a pull request that a maintainer reviews**.

Please also follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## How we collaborate

| You want to… | Use |
| --- | --- |
| Report a bug or request a feature | A [GitHub issue](https://github.com/SK-Consulting-S-A/skc-bc-appsource-billing-patch/issues/new/choose) |
| Ask a usage question | [GitHub Discussions](https://github.com/SK-Consulting-S-A/skc-bc-appsource-billing-patch/discussions) |
| Propose a code or docs change | A pull request **from a fork**, linked to an issue |
| Report a security vulnerability | [SECURITY.md](SECURITY.md) — do **not** open a public issue |

Direct pushes to `main` are blocked. Maintainers review and squash-merge
approved pull requests.

## Issues are required

**Do not open a pull request without a GitHub issue.**

1. Search [existing issues](https://github.com/SK-Consulting-S-A/skc-bc-appsource-billing-patch/issues) first.
2. Open a bug or feature issue with the templates (required fields).
3. Wait for maintainer triage when the change is large or changes public behaviour
   (APIs, posting, billing amounts, permissions). Small docs fixes can proceed
   once the issue exists.
4. Open a pull request that **links the issue** using a closing keyword, for example:

   ```text
   Fixes #123
   ```

   GitHub closing keywords (`Fixes`, `Closes`, `Resolves`) are accepted. A CI
   check fails the pull request if no issue is linked.

Exceptions (no issue required): Dependabot, AL-Go system-file updates, and other
maintainer automation.

## Fork and pull request workflow

External contributors do **not** get write access. Work from a **fork**:

1. Fork this repository.
2. Clone your fork and create a branch from `main`.
3. Keep the branch focused on **one** issue.
4. Push to your fork and open a pull request against
   `SK-Consulting-S-A/skc-bc-appsource-billing-patch` `main`.
5. Fill in the pull request template (issue link is mandatory).
6. A maintainer reviews. Address review comments on the same branch.
7. When approved and CI is green, a maintainer squash-merges.

Do not open pull requests from the upstream repository unless you are a
maintainer. Organization branch rules are designed for internal SK Consulting
work; forks are the path for community contributions.

## What reviewers look for

- Linked issue and a clear description of the problem and the fix
- AL that follows [Microsoft AL guidelines](https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-dev-overview)
  (PascalCase procedures/variables, `DataClassification` on fields, no unused variables)
- No secrets, credentials, or customer data in source or samples
- Tests or a concrete test plan when behaviour changes
- Object IDs stay inside this app's range (`70631050`–`70631150`)
- No drive-by refactors mixed with the functional change

CI runs AL-Go **Pull Request Build** and a secret scan. Fixes must keep those
checks green.

## License of contributions

This project is licensed under the [MIT License](LICENSE). By opening a pull
request, you agree that your contribution is provided under that license and
that you have the right to submit it.

The AppSource listing may still show SK Consulting's product EULA for the
published app. That does not change how source contributions to this repository
are licensed.

## Maintainer notes

- `CODEOWNERS` requires a review from `@skonsbruck` on every pull request to `main`.
- Squash merge only; merged branches are deleted.
- Security reports stay private until a fix is released (see [SECURITY.md](SECURITY.md)).
