# Exylia flavour of Hydrodactyl

The `exylia` branch is an upstream release tag plus a small set of Exylia commits. CI publishes
`ghcr.io/exylia-panel-plugins/hydrodactyl:exylia`, and production (LXC 106, `/opt/hydrodactyl`) runs that tag.

## Changes vs upstream
- `SFTP_HOST`: the hostname shown in a server's SFTP tab (`config/pterodactyl.php` → `ServerTransformer`).
  Production sets it to `sftp-node-cl-1.exylia.net`, because the node FQDN is behind Cloudflare's HTTP proxy.

## Updating to a new upstream release
The weekly *Check upstream release* workflow opens an issue when a new release is out. Follow the steps in that issue.
Keep each change small and isolated (a few files) so rebases stay painless.
