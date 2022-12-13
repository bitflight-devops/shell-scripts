ARG UBUNTU_RELEASE=ubuntu-jammy
FROM myoung34/github-runner:${UBUNTU_RELEASE}
RUN bash -c 'source /etc/lsb-release; \
    case "$DISTRIB_RELEASE" in 18.04|20.04) {\
      GPG_KEY="$(curl -s -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${DISTRIB_RELEASE:-20.04}/Release.key)"; \
      apt-key add - <<<"${GPG_KEY}" > /dev/null 2>&1 || true; \
      } ;; esac; \
    apt-get update -qq -y \
    && apt-get install -qq -y --no-install-recommends "zsh=5.*" > /dev/null 2>&1 \
    && rm -rf /var/lib/apt/lists/* \
    && zsh --version'
