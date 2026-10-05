# Exylia flavour of Hydrodactyl

The `exylia` branch is an upstream release tag plus a small set of Exylia commits. CI publishes
`ghcr.io/exylia-panel-plugins/hydrodactyl:exylia`, and production (LXC 106, `/opt/hydrodactyl`) runs that tag.

## Changes vs upstream
- `SFTP_HOST`: the hostname shown in a server's SFTP tab (`config/pterodactyl.php` → `ServerTransformer`).
  Production sets it to `sftp-node-cl-1.exylia.net`, because the node FQDN is behind Cloudflare's HTTP proxy.

## Updating to a new upstream release
The weekly *Check upstream release* workflow opens an issue when a new release is out. Follow the steps in that issue.
Keep each change small and isolated (a few files) so rebases stay painless.
- Favicon: when a branding logo is set, it replaces the default favicons (panel and admin layouts).
- Lavender theme: `resources/scripts/assets/tailwind.css` re-hues the warm palette to OKLCH hue 300. Lightness is kept,
  so contrast stays the same, and the brand chroma is 70% of the original (pastel). A few hardcoded console/setup colors follow it.
- Server power buttons (Start/Restart/Stop) show in the header on every server page, not only Console.
