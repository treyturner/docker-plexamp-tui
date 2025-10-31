# docker-plexamp-tui

Container image that builds and runs [plexamp-tui](https://github.com/spiercey/plexamp-tui), a terminal UI for controlling Plexamp headless players. The image is rebuilt from upstream release archives and published to Docker Hub and GitHub Container Registry.

## Image highlights
- Reproducible build from upstream refs (tags or branches) via configurable build args (defaults to `v0.2.0`).
- Minimal Alpine runtime with a non-root user and bundled CA certificates.
- First-run authentication helper that automatically launches `plexamp-tui --auth` when no Plex token is present.
- Persistent configuration via `/home/app/.config/plexamp-tui` volume.

## Quick start
Pull a published release (replace the tag as needed):

```bash
docker pull ghcr.io/treyturner/plexamp-tui
# or: docker pull docker.io/treyturner/plexamp-tui
```

Run the container interactively, persisting config in a named volume:

```bash
docker run --rm -it \
  -v plexamp-config:/home/app/.config/plexamp-tui \
  ghcr.io/treyturner/plexamp-tui
```

or bind-mount a config directory from your host:

```bash
docker run --rm -it \
  -v "$(pwd)/config:/home/app/.config/plexamp-tui" \
  ghcr.io/treyturner/plexamp-tui
```
On the first run, the entrypoint detects a missing `plex_auth.json`, launches the upstream authentication flow, and then starts the TUI. Subsequent runs reuse the saved credentials and go straight to the interface.

The container respects the standard `TZ` environment variable if you want to set the timezone explicitly:

```bash
docker run --rm -it \
  -e TZ=US/Central \
  -v plexamp-config:/home/app/.config/plexamp-tui \
  ghcr.io/treyturner/plexamp-tui
```

You can also read-only mount your local timezone file (e.g., `/etc/localtime`) into the container if that's the intent:

```bash
docker run --rm -it \
  -v /etc/localtime:/etc/localtime:ro \
  -v "$(pwd)/config:/home/app/.config/plexamp-tui" \
  ghcr.io/treyturner/plexamp-tui
```

To pass additional flags (or more/alternate commands?), append them after the image reference:

```bash
docker run --rm ghcr.io/treyturner/plexamp-tui:v0.2.0 plexamp-tui --help
```

## Configuration reference
- config lives within `/home/app/.config/plexamp-tui` inside the container
- `plex_auth.json` stores the Plex token that is generated during authentication
- `config.json` (created by the upstream project) holds runtime preferences; edit it on the host if you need to tweak options

### Runtime environment variables
- `PUID` (default `99`): container user ID used to run `plexamp-tui`. Set this to match your host user when bind-mounting.
- `PGID` (default `100`): primary group ID for the runtime user.
- `UMASK` (default `002`): file creation mask applied before launching the app.

The entrypoint recreates the runtime user/group on each start so you can override these values without rebuilding.

## Build the image locally
You can rebuild the container from source, optionally pointing at a different upstream ref or tarball:

```bash
# build with the default upstream ref (v0.2.0 at the moment)
docker build -t local/plexamp-tui .

# pin to a different upstream tag
docker build \
  --build-arg UPSTREAM_REF=v0.3.0 \
  -t local/plexamp-tui:v0.3.0 .

# build against an upstream feature branch
docker build \
  --build-arg UPSTREAM_REF=feature/my-branch \
  -t local/plexamp-tui:feature-my-branch .

# provide a custom tarball URL
docker build \
  --build-arg UPSTREAM_TARBALL=https://example.com/plexamp-tui.tar.gz \
  -t local/plexamp-tui:custom .
```

When you pass a value containing `/` (e.g., `feature/my-branch`), the build assumes it is an upstream branch and fetches `refs/heads/<value>` automatically. Prefix the ref explicitly (e.g., `refs/tags/...`) if you need to target another namespace.

The build stage compiles the Go binary with CGO disabled and ships it in a minimal Alpine base image.

## Continuous integration & delivery
GitHub Actions automation lives under `.github/workflows/`:
- `Build and test PR` builds the Docker image for pull requests, tags it with `vX.Y.Z-pr<number>` and a run-specific suffix, then executes the smoke test.
- `Build and publish dev` runs on pushes to `main` (or manually with a custom upstream ref). It builds the image, runs the smoke test, and pushes tags like `vX.Y.Z-dev` and `vX.Y.Z-dev-<run-id>` to Docker Hub and GHCR.
- `Promote tag` retags an existing `-dev` image to a release (`vX.Y.Z`) and optionally `latest` using `docker buildx imagetools create`.

Each workflow relies on composite actions in `.github/actions/`:
- `build` computes tag names, configures Buildx, and performs the Docker build.
- `test` runs the smoke test against the built image.
- `publish` authenticates with registries and pushes the requested references.

## Versioning & tags
- `UPSTREAM_REF` (default `v0.2.0`) determines which `plexamp-tui` ref (tag or branch) is bundled.
- Dev builds are tagged using a sanitized version of the upstream ref (e.g., `v0.3.0-dev` or `feature-my-branch-dev`) plus a unique run suffix for traceability.
- Release tags are promoted from dev builds once validated, ensuring identical image digests across registries.

## Troubleshooting
- Make sure your terminal is prepared for a full-screen TUI; use `docker run -it` so the container has an interactive TTY.
- If authentication fails, remove the existing `plex_auth.json` from your mounted config directory and rerun the container to trigger the login flow again.
- When bind-mounting configuration, ensure the host directory is writable by the configured UID/GID (defaults `99:100`). The entrypoint checks this and exits early with a helpful message if it cannot create files.
- Upstream issues or regressions should be reported to [spiercey/plexamp-tui](https://github.com/spiercey/plexamp-tui); container-specific problems can be filed here.

## Licensing
The upstream `plexamp-tui` project is licensed under MIT. Each container includes the upstream license at `/usr/share/licenses/plexamp-tui/LICENSE`; review it to understand the terms before redistributing the image.
