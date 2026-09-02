# Renance study-api — production image (Render / Fly / any Docker host).
#
# Build context is the REPO ROOT (the API embeds the mock question library):
#   docker build -f apps/study-api/Dockerfile .
#
# Runtime env: DATABASE_URL (Neon pooled URI), JWT_SECRET, optional
# GOOGLE_CLIENT_ID, WEB_ORIGIN. PORT is honored (Render injects it).

FROM golang:1.27-alpine AS build
WORKDIR /src
COPY apps/study-api/go.mod apps/study-api/go.sum ./
RUN go mod download
COPY apps/study-api/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/study-api ./cmd/api

FROM alpine:3.20
RUN apk add --no-cache ca-certificates \
 && adduser -D -H -u 15001 renance
WORKDIR /app
COPY --from=build /out/study-api /app/study-api
COPY data/ /app/data/
USER renance
ENV DATA_DIR=/app/data
ENV PORT=10000
EXPOSE 10000
ENTRYPOINT ["/app/study-api"]
