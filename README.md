# Anycast Scout GUI

> [!WARNING]
> **In Development / Alpha.** Anycast Scout GUI is under active development.
> UX, bundled backend behavior, and release artifacts may change before a stable
> release. Review generated targets and configs before using them in production
> workflows.

Anycast Scout GUI helps find a working Cloudflare edge IP for a CDN/BYOIP-style
`sing-box` outbound. It is built for cases where the outbound hostname, TLS/SNI,
transport path, and credentials stay in a private `sing-box` config, while the
candidate IP is rotated until one actually works through that outbound.

![Anycast Scout GUI dashboard](assets/screenshot.png)

The app packages the Rust `anycast-scout` backend into a desktop interface for
macOS and Linux. It discovers candidate IPs from ASN/BGP data, validates that a
candidate can serve Cloudflare edge traffic, then runs a headless `sing-box`
URLTest against the selected outbound. Results are ranked by scan latency,
optional speed checks, and final outbound compatibility.

The goal is to reduce manual trial and error: instead of copying IPs into a
config one by one, Anycast Scout keeps the discovery, probing, outbound checks,
CSV/JSON artifacts, and resumable sessions in one workflow.

## How It Works

Discovery starts from configured ASNs and BGP sources, including originated and
AS-path prefixes when that scope is enabled. The scanner expands those prefixes
into candidate targets, resolves Cloudflare-controlled validation hostnames to
each candidate IP, and requires a minimum download before marking the scan
result as valid.

When a private `sing-box` config is selected, the backend reads the configured
outbound tag, copies that outbound into a temporary headless config, replaces
only its `server` with the candidate IP, and starts `sing-box` locally for a
URLTest. A candidate is considered usable only when the delay check succeeds and
the required bytes can be downloaded through that temporary proxy path.

## Releases

Download the latest desktop build from
[GitHub Releases](https://github.com/Pingle-Software/Anycast-Scout-GUI/releases).
Published bundles currently target macOS and Linux and include the
`anycast-scout` backend.

## Connect Config

Anycast Scout GUI does not ship private `sing-box` credentials or ready-to-use
configs. Choose your own JSON config in Settings before running outbound checks.
Local `config.json`, `.env*`, and `sing-box`-style JSON files are ignored by
default.
