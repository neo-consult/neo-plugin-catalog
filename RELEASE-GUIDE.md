# Neo Plugin Releases

## Repositories

Create these public repositories under `neo-consult` and copy the respective plugin directory into the repository root:

- `neo-dashboard`
- `neo-calendar`
- `neo-surveys`
- `neo-surveys-extern`
- `neo-plugin-manager`

Copy `release-workflow.yml` to `.github/workflows/release.yml` in each repository.

## Release process

1. Increase the WordPress plugin header version and its matching PHP version constant.
2. Commit and push the plugin repository.
3. Create and push a matching tag, for example `v1.2.3`.
4. The GitHub workflow verifies the header version, creates `<plugin-slug>.zip`, calculates SHA-256, publishes the release and updates `plugins.json` automatically.
5. In WordPress, use **Dashboard → Updates** to install an available update.

## Required GitHub secret

Each plugin repository requires the Actions secret `NEO_CATALOG_TOKEN`. Create a fine-grained personal access token for account `neo-consult` with **Contents: Read and write** access limited to repository `neo-plugin-catalog`, then add it as an Actions secret with that exact name in every plugin repository. The token is only used to commit the generated release metadata to the catalog.

The ZIP must contain exactly one top-level plugin directory, named after the plugin slug.
