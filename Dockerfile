# syntax=docker/dockerfile:1
###
# Build Image
###
FROM python:3.9-slim-bullseye AS compile-image

# Update the base image and install requirements
# build-essentials: contains build tools you need to build Python extensions
# python3-dev: contains the header files you need to build Python extensions (needed for ARM)
# gfortran:
# libblas-dev:
# liblapack-dev:
# libjpeg62-turbo-dev: needed for build pillow
# https://pillow.readthedocs.io/en/stable/installation.html#building-on-linux
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get upgrade --assume-yes \
    && apt-get install --assume-yes --no-install-recommends \
    build-essential=12.9 \
    gfortran=4:10.2.1-1 \
    libblas-dev=3.9.0-3 \
    libjpeg62-turbo-dev=1:2.0.6-4 \
    liblapack-dev=3.9.0-3 \
    python3-dev=3.9.2-3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python3 -m venv /app
# Make sure we use the virtualenv:
ENV PATH="/app/bin:$PATH"

COPY requirements.txt .

# Use docker buildkit for faster builds and cache pip
RUN --mount=type=cache,mode=0755,target=/root/.cache/pip python3 -m pip install --upgrade pip wheel \
    && python3 -m pip install --upgrade --requirement requirements.txt

COPY . /app

###
# Runable Image
###

FROM python:3.9-slim-bullseye AS runtime-image

# Update the base image and install requirements
# libatlas3-base:
# libjpeg62-turbo: needed to run pillow
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get upgrade --assume-yes \
    && apt-get install --assume-yes --no-install-recommends \
    libatlas3-base=3.10.3-10 \
    libjpeg62-turbo=1:2.0.6-4 \
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
