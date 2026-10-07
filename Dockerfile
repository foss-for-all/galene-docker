# syntax=docker/dockerfile:1

ARG GO_VERSION=1.27
ARG GALENE_REF=galene-1.2.1
ARG MEDIAPIPE_VERSION=1.1.0
ARG MEDIAPIPE_SHA256=46fc3d3d13fa5de631915929d045be2f74bb32e909d7a5b3a322b28976f54165
ARG SEGMENTER_SHA256=191ac9529ae506ee0beefa6b2c945a172dab9d07d1e802a290a4e4038226658b

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS build
ARG GALENE_REF
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
ADD https://github.com/jech/galene.git#${GALENE_REF} .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags='-s -w' -o /out/ . ./galenectl
RUN mkdir -p /out/state/data /out/state/groups /out/state/recordings

FROM --platform=$BUILDPLATFORM busybox:1.38.0 AS mediapipe
ARG MEDIAPIPE_VERSION
ARG MEDIAPIPE_SHA256
ARG SEGMENTER_SHA256
ADD --checksum=sha256:${MEDIAPIPE_SHA256} \
    https://registry.npmjs.org/@mediapipe/tasks-vision/-/tasks-vision-${MEDIAPIPE_VERSION}.tgz /tmp/tasks-vision.tgz
ADD --checksum=sha256:${SEGMENTER_SHA256} \
    https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite \
    /out/models/selfie_segmenter.tflite
RUN tar -xzf /tmp/tasks-vision.tgz -C /tmp \
    && mkdir -p /out/wasm \
    && cp /tmp/package/vision_bundle.mjs /out/ \
    && cp /tmp/package/wasm/vision_wasm_internal.* /tmp/package/wasm/vision_wasm_nosimd_internal.* /out/wasm/

FROM gcr.io/distroless/static-debian13:nonroot AS minimal
WORKDIR /galene
COPY --from=build /out/galene /galene/galene
COPY --from=build /src/static /galene/static
COPY --from=build /src/LICENCE /galene/LICENCE
COPY --from=build --chown=65532:65532 /out/state/ /galene/
EXPOSE 8443 1194/tcp 1194/udp
ENTRYPOINT ["/galene/galene"]

FROM minimal AS full
ENV XDG_CONFIG_HOME=/galene/data
COPY --from=build /out/galenectl /galene/galenectl
COPY --from=mediapipe /out /galene/static/third-party/tasks-vision
