# ralphex images

Custom [ralphex](https://github.com/umputun/ralphex) images for running autonomous AI-assisted development on Java/Maven and Python projects.

## Contents

- Base for both images: `ghcr.io/umputun/ralphex-go:latest` (Claude Code, codex, ralphex binary, git, fzf, etc.)
- Java image: OpenJDK 21 + Maven 3.9.9
- Python image: Python 3 + pip + uv + native build toolchain

## Java image

```bash
docker build --pull -t ralphex-java .
```

Use:

```bash
RALPHEX_IMAGE=ralphex-java ralphex-dk docs/plans/your-plan.md
```

## Python image

```bash
docker build --pull -f Dockerfile.python -t ralphex-python .
```

Use:

```bash
RALPHEX_IMAGE=ralphex-python ralphex-dk docs/plans/your-plan.md
```

Or with the web dashboard:

```bash
RALPHEX_IMAGE=ralphex-python ralphex-dk --serve docs/plans/your-plan.md
```

## Updating tool versions

- Java image Maven version: edit the `MAVEN_VERSION` build arg in `Dockerfile`, then rebuild.
- Python image tooling: edit `Dockerfile.python`, then rebuild.

## Updating the base image

Both images currently use `ghcr.io/umputun/ralphex-go:latest` in the `FROM` line.
To rebuild against the latest upstream base image, pull fresh layers during the build:

```bash
docker build --pull -t ralphex-java .
docker build --pull -f Dockerfile.python -t ralphex-python .
```

If you want a repeatable base version instead of tracking `latest`, change the `FROM` line in `Dockerfile` and `Dockerfile.python` to a specific upstream tag, then rebuild and smoke-test the images.

## Smoke tests

```bash
docker run --rm ralphex-java java -version
docker run --rm ralphex-java mvn -version
docker run --rm --entrypoint /bin/sh ralphex-python -lc 'python3 --version && pip --version && uv --version'
```

## Cron automation note

On macOS, cron jobs that call Docker Desktop need a `PATH` that includes Docker Desktop's helper binaries, not just the `docker` CLI path. Without that, builds can fail under cron with `docker-credential-desktop` lookup errors even though the same command works interactively.

Example:

```cron
PATH=/Applications/Docker.app/Contents/Resources/bin:/Applications/Docker.app/Contents/MacOS:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

Also make sure Docker Desktop is running when the scheduled job fires.

## See also

- [ralphex documentation](https://github.com/umputun/ralphex)
- [AGENTS.md](AGENTS.md) — instructions for AI agents working inside this container
