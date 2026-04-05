# AGENTS.md

Instructions for AI agents (Claude Code, codex, etc.) working inside this container or maintaining this repository.

---

## Working inside the container

This repository ships multiple ralphex image variants. Use the image that matches the project you are working on.

### Java image

```bash
mvn clean install
```

### Test

```bash
mvn test
```

### Run a single test class

```bash
mvn test -Dtest=MyTestClass
```

### Skip tests (build only)

```bash
mvn clean package -DskipTests
```

### Check Java and Maven versions

```bash
java -version
mvn -version
```

### Environment variables set in the container

| Variable | Value |
|---|---|
| `JAVA_HOME` | `/usr/lib/jvm/java-21-openjdk` |
| `MAVEN_HOME` | `/usr/local/maven` |
| `RALPHEX_DOCKER` | `1` |

### Python image

This image provides Python 3, pip, uv, and a native build toolchain. Use them directly — no install steps needed.

### Check Python tool versions

```bash
python3 --version
pip --version
uv --version
```

### Tips

- Maven's local repository (`.m2/`) is under `/home/app/.m2` inside the Java image. To cache it across runs, mount a host directory: `RALPHEX_EXTRA_VOLUMES=/host/.m2:/home/app/.m2`.
- The working directory is `/workspace` (your project is mounted here).
- Avoid `sudo` — build tools are on `PATH` for the `app` user.
- Prefer `mvn -B` (batch mode) in scripts to suppress interactive progress output.

---

## Maintaining this repository

This repo contains a small set of Dockerfile variants that extend the upstream ralphex image for language-specific work.
Keep it minimal — no application code, no CI config beyond what's needed to build and push the image.

### Structure

```
Dockerfile         — Java 21 + Maven image; extends ghcr.io/umputun/ralphex-go:latest
Dockerfile.python  — Python 3 + pip + uv image; extends ghcr.io/umputun/ralphex-go:latest
README.md          — usage instructions
AGENTS.md          — this file
CLAUDE.md          — must stay identical to AGENTS.md
```

### How to update

- **Maven version**: change `MAVEN_VERSION` build arg default in `Dockerfile`, rebuild and test.
- **Python tooling**: update packages or installer steps in `Dockerfile.python`, rebuild and test.
- **Base image**: both `FROM` lines track `:latest`; pin to a specific tag when stability matters.
- **Java version**: swap `openjdk21-jdk` for `openjdk17-jdk` (or whatever apk provides) and update `JAVA_HOME`.
- **Maven offline cache (seed project)**: The `Dockerfile` runs a minimal seed `pom.xml` as the `app` user during build to pre-download plugins and test libraries into `/home/app/.m2`. This is required for `mvn -o` (offline mode) to work. The seed uses `spring-boot-starter-parent:3.3.6` as its parent so the Spring Boot BOM manages most versions automatically. It explicitly caches: `spring-boot-starter-test` (JUnit Jupiter, Mockito, AssertJ), `mockito-inline`, **`byte-buddy-agent`** (critical — projects pass it as `-javaagent` in surefire's `argLine`; without it offline tests fail), `mockk-jvm`, `springmockk`, `kotest-assertions-core-jvm`, `testcontainers` (PostgreSQL), `maven-surefire-plugin:3.2.5`, `maven-failsafe-plugin:3.2.5`, `jacoco-maven-plugin:0.8.11`. When updating, inspect the actual project poms first to identify what versions they require, then update the seed to match.

### Build and smoke-test locally

```bash
docker build --pull -t ralphex-java .
docker build --pull -f Dockerfile.python -t ralphex-python .
docker run --rm ralphex-java java -version
docker run --rm ralphex-java mvn -version
docker run --rm --entrypoint /bin/sh ralphex-python -lc 'python3 --version && pip --version && uv --version'
```

### Automation note

- On macOS cron jobs, include both `/Applications/Docker.app/Contents/Resources/bin` and `/Applications/Docker.app/Contents/MacOS` in `PATH` before calling Docker. This prevents `docker-credential-desktop` lookup failures that do not appear in interactive shells.
- Scheduled rebuild jobs depend on Docker Desktop being running when the cron entry fires.

### Dockerfile authoring rules

- **Use BuildKit heredoc syntax for multi-step `RUN` blocks.** Always add `# syntax=docker/dockerfile:1` as the first line and wrap multi-command blocks (especially those that write files via shell heredoc and then run commands) in `RUN <<'SHELL' ... SHELL`. The alternative `cat > file <<'EOF' ... EOF && next-cmd` is invalid: Docker ends the `RUN` instruction at the first line without `\`, turning everything after the heredoc terminator into new (broken) Dockerfile instructions.

### Container lifecycle

- **Do not manually recreate `ralphex-java-container` or `ralphex-python-container`.** These are managed by the `ralphex` binary with correct parameters (entrypoint, user, env vars, volume mounts). After rebuilding an image, stop and remove the old container (`docker stop <name> && docker rm <name>`) and let `ralphex` recreate it on next run.
- **`docker ps` showing an image ID instead of a name is normal after a rebuild.** It means the container is still running from the old image layer. Restarting the container (remove + let `ralphex` recreate) resolves it.

### Do not

- Add application source code to this repo.
- Add unrelated tools to these Dockerfiles — keep each image focused.
- Commit secrets or credentials.
