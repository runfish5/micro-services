# Database growth guard: bash, psql, curl and jq. Nothing else.
# Build context is this directory (on Railway: Root Directory = projects/n8n/14_db-janitor).
FROM alpine:3.20
RUN apk add --no-cache bash curl jq postgresql16-client busybox-extras
WORKDIR /guard
COPY sql ./sql
COPY service ./service
USER nobody
CMD ["bash", "/guard/service/guard-loop.sh"]
