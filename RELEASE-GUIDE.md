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
2. Update `plugins.json` in repository `neo-plugin-catalog` with the same version and download URL.
3. Commit and push the plugin repository.
4. Create and push a matching tag, for example `v1.2.3`.
5. The GitHub workflow creates `<plugin-slug>.zip` and attaches it to the GitHub Release.
6. Publish the matching `plugins.json` update to the catalog repository.
7. In WordPress, use **Dashboard → Updates** to install an available update.

The ZIP must contain exactly one top-level plugin directory, named after the plugin slug.
