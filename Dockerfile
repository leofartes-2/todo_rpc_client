# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM alpine AS protoc
ARG BUILDPLATFORM TARGETOS TARGETARCH

# Download the protoc binary from github.
RUN export PROTOC_VERSION=28.3 \
    && export PROTOC_ARCH=$(uname -m | sed s/aarch64/aarch_64/) \
    && export PROTOC_OS=$(echo $TARGETOS | sed s/darwin/linux/) \
    && export PROTOC_ZIP=protoc-$PROTOC_VERSION-$PROTOC_OS-$PROTOC_ARCH.zip \
    && echo "downloading: " https://github.com/protocolbuffers/protobuf/releases/download/v$PROTOC_VERSION/$PROTOC_ZIP \
    && wget https://github.com/protocolbuffers/protobuf/releases/download/v$PROTOC_VERSION/$PROTOC_ZIP \
    && unzip -o $PROTOC_ZIP -d /usr/local bin/protoc 'include/*' \
    && rm -f $PROTOC_ZIP


# ARG GO_VERSION=1.22.9
# FROM --platform=$BUILDPLATFORM golang:${GO_VERSION} AS build.
FROM --platform=$BUILDPLATFORM golang:1.22.9 AS build

# Copy the protoc library and the protobuf includes.
COPY --from=protoc /usr/local/bin/protoc /usr/local/bin/protoc
COPY --from=protoc /usr/local/include/google /usr/local/include/google

# Download protoc plugins
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Copy proto files into go/src/todo_rpc_proto.
WORKDIR /go/src/todo_rpc_proto
COPY ./todo_rpc_proto .

# Generate code out of proto files.
WORKDIR /go
ENV MODULE=github.com/leofartes-2/todorpcproto
RUN protoc \
    --go_out=src \
    --go_opt=module=$MODULE \
    --go-grpc_out=src \
    --go-grpc_opt=module=$MODULE \
    src/todo_rpc_proto/*.proto

# Copy code into go/src/app
WORKDIR /go/src/app
COPY ./todo_rpc_client .

# Install git and openssh-client package
RUN apt-get update \
    && apt-get install -y --no-install-recommends git openssh-client \
    && apt-get clean

# Get the necesary public keys
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN git config --global url."git@github.com:".insteadof "https://github.com"

# Inform Go that proto module is private.
RUN go env -w GOPRIVATE="github.com/leofartes-2/todo_rpc_proto"

# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /go/pkg/mod/ to speed up subsequent builds.
# Leverage bind mounts to go.sum and go.mod to avoid having to copy them into
# the container.
RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,source=./todo_rpc_client/go.sum,target=go.sum \
    --mount=type=bind,source=./todo_rpc_client/go.mod,target=go.mod

RUN --mount=type=ssh go mod download -x && go mod verify
RUN --mount=type=ssh CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -ldflags="-s -w" -o /go/bin/app /go/src/app/cmd/main.go


FROM --platform=$BUILDPLATFORM alpine:latest AS final
ARG SERVER_ADDR="0.0.0.0:50051"

# Install any runtime dependencies that are needed to run your application.
# Leverage a cache mount to /var/cache/apk/ to speed up subsequent builds.
RUN --mount=type=cache,target=/var/cache/apk \
    apk --update add \
        ca-certificates \
        tzdata \
        && \
        update-ca-certificates

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser
USER appuser

# # Copy certs onto /certs
# COPY ./certs/ca_cert.pem ./certs/ca_cert.pem

# Copy the previously built binary into a smaller image.
COPY --from=build /go/bin/app /

ENV SERVER_ADDR_ENV=${SERVER_ADDR}
CMD [ "/app", "${SERVER_ADDR_ENV}" ]
