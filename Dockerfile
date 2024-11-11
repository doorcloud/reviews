# Copyright Istio Authors
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

FROM gradle:8.6.0-jdk8 AS builder

WORKDIR /app

# Not sure why but we need root to build. Ignore lint error, this is for a multistage builder so it doesn't matter.
# hadolint ignore=DL3002
USER 0
COPY . /home/gradle

RUN gradle build

FROM open-liberty:24.0.0.1-kernel-slim-java17-openj9

ENV SERVERDIRNAME=reviews

COPY --from=builder /home/gradle/reviews-wlpcfg/servers/LibertyProjectServer/ /opt/ol/wlp/usr/servers/defaultServer/
# Not sure why but we need root to build, but without it buildx cannot get network connectivity. We swap to 1001 later.
# hadolint ignore=DL3002
USER 0
RUN /opt/ol/wlp/bin/featureUtility installServerFeatures  --acceptLicense /opt/ol/wlp/usr/servers/defaultServer/server.xml --verbose && \
    chmod -R g=rwx /opt/ol/wlp/output/defaultServer/
USER 1001

ARG service_version
ARG enable_ratings
ARG star_color
ENV SERVICE_VERSION=${service_version:-v1}
ENV ENABLE_RATINGS=${enable_ratings:-false}
ENV STAR_COLOR=${star_color:-black}

RUN curl -L https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.29.0/opentelemetry-javaagent.jar -o /app/opentelemetry-javaagent.jar

ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://tempo-simplest-distributor.door-tracing.svc.cluster.local:4318"
ENV OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
ENV OTEL_SERVICE_NAME="kubecon"
ENV OTEL_LOG_LEVEL="debug"
ENV OTEL_PROPAGATORS="tracecontext"
ENV JAVA_TOOL_OPTIONS="-javaagent:/app/opentelemetry-javaagent.jar"

CMD ["/opt/ol/wlp/bin/server", "run", "defaultServer"]
