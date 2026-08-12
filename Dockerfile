#
# Spiderfoot Dockerfile
#

FROM alpine:3.12.4 AS build

ARG REQUIREMENTS=requirements.txt

RUN apk add --no-cache \
    gcc \
    git \
    curl \
    python3 \
    python3-dev \
    py3-pip \
    swig \
    tinyxml-dev \
    musl-dev \
    openssl-dev \
    libffi-dev \
    libxslt-dev \
    libxml2-dev \
    jpeg-dev \
    openjpeg-dev \
    zlib-dev \
    cargo \
    rust \
    nodejs \
    npm

RUN python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

COPY $REQUIREMENTS requirements.txt ./

RUN pip3 install -U pip
RUN pip3 install -r "$REQUIREMENTS"

# Install SpiderFoot frontend dependencies
COPY spiderfoot/static/package.json /tmp/spiderfoot-static/package.json
RUN cd /tmp/spiderfoot-static && npm install --omit=dev


FROM alpine:3.13.0

WORKDIR /home/spiderfoot

# Place database and logs outside installation directory
ENV SPIDERFOOT_DATA=/var/lib/spiderfoot
ENV SPIDERFOOT_LOGS=/var/lib/spiderfoot/log
ENV SPIDERFOOT_CACHE=/var/lib/spiderfoot/cache

# Install runtime dependencies
RUN apk --update --no-cache add \
    python3 \
    musl \
    openssl \
    libxslt \
    tinyxml \
    libxml2 \
    jpeg \
    zlib \
    openjpeg \
    && addgroup spiderfoot \
    && adduser -G spiderfoot \
       -h /home/spiderfoot \
       -s /sbin/nologin \
       -g "SpiderFoot User" \
       -D spiderfoot \
    && rm -rf /var/cache/apk/* \
    && rm -rf /lib/apk/db \
    && rm -rf /root/.cache \
    && mkdir -p "$SPIDERFOOT_DATA" \
    && mkdir -p "$SPIDERFOOT_LOGS" \
    && mkdir -p "$SPIDERFOOT_CACHE" \
    && chown spiderfoot:spiderfoot "$SPIDERFOOT_DATA" \
    && chown spiderfoot:spiderfoot "$SPIDERFOOT_LOGS" \
    && chown spiderfoot:spiderfoot "$SPIDERFOOT_CACHE"

# Copy SpiderFoot application
COPY . .

# Copy Python virtual environment
COPY --from=build /opt/venv /opt/venv

# Copy frontend dependencies
COPY --from=build /tmp/spiderfoot-static/node_modules \
    /home/spiderfoot/spiderfoot/static/node_modules

ENV PATH="/opt/venv/bin:$PATH"

USER spiderfoot

EXPOSE 5001

# Run SpiderFoot
CMD ["/bin/sh", "-c", "/opt/venv/bin/python sf.py -l 0.0.0.0:${PORT:-5001}"]