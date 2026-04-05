# syntax=docker/dockerfile:1
FROM ghcr.io/umputun/ralphex-go:latest

# Alpine-based image — use apk; download Maven directly since apk's version is outdated
ARG MAVEN_VERSION=3.9.9

USER root

RUN apk add --no-cache openjdk21-jdk wget && \
    wget -qO- "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
        | tar -xz -C /usr/local && \
    ln -s /usr/local/apache-maven-${MAVEN_VERSION} /usr/local/maven && \
    rm -rf /var/cache/apk/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV MAVEN_HOME=/usr/local/maven
ENV PATH="${PATH}:${MAVEN_HOME}/bin"
# JAVA_TOOL_OPTIONS applies to all JVMs (Maven orchestrator + surefire forks).
# MAVEN_OPTS is appended after JAVA_TOOL_OPTIONS on the Maven JVM, so -Xmx1g wins for Maven (last flag wins).
# Surefire forks get -Xmx2g from JAVA_TOOL_OPTIONS only.
ENV MAVEN_OPTS="-Xmx1g"
ENV JAVA_TOOL_OPTIONS="-Xmx2g -Duser.timezone=UTC"
ENV TZ=UTC

USER app

# Pre-download plugins and test libraries so the image works in offline mode.
# Versions match the sportybet-inbox / sportybet-crm-profile projects.
# byte-buddy-agent is critical: both projects configure maven-surefire to use it as a javaagent.
RUN <<'SHELL'
set -e
mkdir -p /tmp/seed
cat > /tmp/seed/pom.xml << 'POM'
<project>
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.6</version>
  </parent>
  <groupId>seed</groupId><artifactId>seed</artifactId><version>1</version>
  <properties>
    <java.version>21</java.version>
  </properties>
  <dependencies>
    <!-- Spring Boot test slice: pulls in JUnit Jupiter, Mockito, AssertJ, Hamcrest -->
    <dependency>
      <groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <!-- Mockito inline mock maker (needed alongside mockito-core for final/static mocking) -->
    <dependency>
      <groupId>org.mockito</groupId><artifactId>mockito-inline</artifactId>
      <version>5.2.0</version><scope>test</scope>
    </dependency>
    <!-- Byte-Buddy agent — surefire argLine uses this jar as -javaagent -->
    <dependency>
      <groupId>net.bytebuddy</groupId><artifactId>byte-buddy-agent</artifactId>
      <scope>test</scope>
    </dependency>
    <!-- Kotlin test libraries -->
    <dependency>
      <groupId>io.mockk</groupId><artifactId>mockk-jvm</artifactId>
      <version>1.14.4</version><scope>test</scope>
    </dependency>
    <dependency>
      <groupId>com.ninja-squad</groupId><artifactId>springmockk</artifactId>
      <version>4.0.2</version><scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.kotest</groupId><artifactId>kotest-assertions-core-jvm</artifactId>
      <version>5.9.1</version><scope>test</scope>
    </dependency>
    <!-- Testcontainers (PostgreSQL) -->
    <dependency>
      <groupId>org.testcontainers</groupId><artifactId>junit-jupiter</artifactId>
      <version>1.19.8</version><scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId><artifactId>postgresql</artifactId>
      <version>1.19.8</version><scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId>
        <version>3.2.5</version>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId><artifactId>maven-failsafe-plugin</artifactId>
        <version>3.2.5</version>
      </plugin>
      <plugin>
        <groupId>org.jacoco</groupId><artifactId>jacoco-maven-plugin</artifactId>
        <version>0.8.11</version>
      </plugin>
    </plugins>
  </build>
</project>
POM
mvn -B -f /tmp/seed/pom.xml dependency:resolve test --fail-never
rm -rf /tmp/seed
SHELL
