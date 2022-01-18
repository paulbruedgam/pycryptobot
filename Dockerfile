# syntax=docker/dockerfile:1

# Build Image
FROM python:3.9-slim-bullseye AS compile-image

# Update the base image and install requirements
# - Base build tools
#   - build-essentials: contains build tools (e.g. gcc or g++) you need to build Python extensions
#   - python3-dev: contains the header files you need to build Python extensions (needed for ARM)
#
# - Pillow (https://pillow.readthedocs.io/en/stable/installation.html#building-on-linux)
#   - Python packages: setuptools tk
#   - Linux packages (dev): libfreetype6-dev libfribidi-dev libharfbuzz-dev libjpeg62-turbo-dev
#                           liblcms2-dev libopenjp2-7-dev libtiff5-dev libwebp-dev libxcb1-dev
#                           tcl8.6-dev tk8.6-dev zlib1g-dev
#
#   - Linux packages (prod): libfreetype6 libjpeg62-turbo libopenjp2-7 libtiff5 libxcb1
#
# - matplotlib (https://matplotlib.org/stable/devel/dependencies.html)
#   - Python packages: NumPy, Pillow
#   - Linux packages (dev): gcc libfreetype6-dev
#   - ToDo:
#       - https://matplotlib.org/stable/devel/testing.html#run-the-tests
#       - Evaluate python3 -m pytest --pyargs matplotlib.tests
#
# - NumPy (https://numpy.org/devdocs/user/building.html)
#   - Python packages: Cython
#   - Linux packages (dev): gcc gfortran libatlas-base-dev liblapack-dev libopenblas-dev
#   - Linux packages (prod): libatlas3-base libopenblas-base
#   - ToDo:
#       - https://numpy.org/devdocs/dev/development_environment.html#running-tests
#       - Evaluate python3 -c 'import numpy as np; np.test("full", verbose=2)'
#
# - pandas (https://pandas.pydata.org/docs/getting_started/install.html#dependencies)
#   - Python packages: NumPy, python-dateutil, pytz
#   - ToDo:
#       - https://pandas.pydata.org/docs/getting_started/install.html#running-the-test-suite
#       - Evaluate python3 -c 'import pandas as pd; pd.test()'
#
# - scipy (https://scipy.github.io/devdocs/building/linux.html#id1)
#   - Linux packages (dev): gcc g++ gfortran liblapack-dev libopenblas-dev
#   - Linux packages (prod): libatlas3-base libopenblas-base
#
# - statsmodels (https://www.statsmodels.org/stable/install.html)
#   - Python packages: Cython, NumPy, Pandas, SciPy, Patsy
#
# Note: OpenBLAS packages not available on all arm versions. Using libblas-dev and libblas3 instead
#
# hadolint ignore=DL3008
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update -qq \
    && apt-get upgrade -qq \
    && apt-get install --no-install-recommends -qq \
        build-essential \
        gfortran \
        libatlas-base-dev \
        libblas-dev \
        libjpeg62-turbo-dev \
        liblapack-dev \
        python3-dev \
        > /dev/null \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /app

WORKDIR /app

# Make sure we use the virtualenv:
ENV PATH="/app/bin:$PATH"

# Use as many cores as possible during build of c extensions
ENV MAKEFLAGS="-j$(nproc)"

COPY requirements.txt .

ARG CACHE_DIR="/root/.cache/pip"
# Use docker buildkit for faster builds and cache pip
# hadolint ignore=DL3013,DL3042
RUN --mount=type=cache,mode=0755,target=${CACHE_DIR} \
    python3 -m pip install \
      --upgrade \
      numpy \
      pip \
      setuptools \
      wheel \
    && python3 -m pip install \
      --upgrade \
      --cache-dir ${CACHE_DIR} \
      --requirement requirements.txt \
    && python3 -m pip uninstall --yes wheel

COPY . /app

# Runtime Image
FROM python:3.9-slim-bullseye AS runtime-image

ARG REPO=whittlem/pycryptobot

LABEL org.opencontainers.image.source https://github.com/${REPO}

# Update the base image and install requirements
# Explanations for packages in dev part
# hadolint ignore=DL3008
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get upgrade --assume-yes \
    && apt-get install --assume-yes --no-install-recommends \
        libatlas3-base \
        libfreetype6 \
        libjpeg62-turbo \
        libopenjp2-7 \
        libtiff5 \
        libxcb1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1000 pycryptobot \
    && useradd -r -u 1000 -g pycryptobot pycryptobot \
    && mkdir -p /app/.config/matplotlib \
    && chown -R pycryptobot:pycryptobot /app

WORKDIR /app

COPY --chown=pycryptobot:pycryptobot --from=compile-image /app /app

USER pycryptobot

# Make sure we use the virtualenv:
ENV PATH="/app/bin:$PATH"

# Make sure we have a config dir for matplotlib when we not the root user
ENV MPLCONFIGDIR="/app/.config/matplotlib"

# Pass parameters to the container run or mount your config.json into /app/
ENTRYPOINT [ "python3", "-u", "pycryptobot.py" ]
