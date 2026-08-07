FROM mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm

# Pre-install python3-yaml so BMAD's bmad_init.py works immediately
# Pre-install pre-commit for commit hygiene hooks (avoids runtime pip install)
# The base image has Python but no pip — apt is the only reliable method
RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends python3-yaml pre-commit \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
