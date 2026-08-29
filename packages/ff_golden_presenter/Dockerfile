# syntax=docker/dockerfile:1.7

ARG SDK_IMAGE=dart:stable
FROM ${SDK_IMAGE} AS generator

WORKDIR /workspace

ARG PUB_GET_COMMAND="dart pub get"
COPY pubspec.yaml ./
# The package normally resolves through the parent Pub workspace. A standalone
# Docker build intentionally detaches it so the generator can use dart:stable.
RUN printf 'resolution:\n' > pubspec_overrides.yaml && \
    sh -c "${PUB_GET_COMMAND}"

COPY . .

ARG GOLDEN_INPUT=example/goldens
ARG REPORT_TITLE="FF Golden Presenter demo"
ARG OPTIMIZATION_PROFILE=none
ARG OPTIMIZATION_BACKEND=auto
ARG OPTIMIZATION_JOBS=4
ARG INSTALL_TOOLS=false

RUN if [ "${INSTALL_TOOLS}" = "true" ] && [ "${OPTIMIZATION_PROFILE}" != "none" ]; then \
      apt-get update && \
      dart run ff_golden_presenter doctor \
        --profile "${OPTIMIZATION_PROFILE}" \
        --backend "${OPTIMIZATION_BACKEND}" \
        --install-tools && \
      rm -rf /var/lib/apt/lists/*; \
    fi

RUN dart run ff_golden_presenter build \
      --input "${GOLDEN_INPUT}" \
      --output-directory /publication \
      --report-file index.html \
      --title "${REPORT_TITLE}" \
      --profile "${OPTIMIZATION_PROFILE}" \
      --backend "${OPTIMIZATION_BACKEND}" \
      --jobs "${OPTIMIZATION_JOBS}" \
      --clean

FROM nginxinc/nginx-unprivileged:stable-alpine AS runtime

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=generator /publication/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
