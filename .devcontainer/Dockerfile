FROM mcr.microsoft.com/devcontainers/java:1-21-bookworm

ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends curl unzip ca-certificates postgresql-client \
    && sudo rm -rf /var/lib/apt/lists/*
