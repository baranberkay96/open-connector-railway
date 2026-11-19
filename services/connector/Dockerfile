# OpenConnector v1.10.0 (released 2026-11-12), the upstream multi-arch GHCR image pinned by digest.
# The only addition is railway-start.sh: it checks the deploy-form values, runs the PostgreSQL
# migrations once the database answers, then hands over to the image's own entrypoint.
ARG OPEN_CONNECTOR_IMAGE=ghcr.io/oomol-lab/open-connector:v1.10.0@sha256:508acc68b237ab75e5afab35a4df2f2a864ab66520b2913623568f6086bab83a
FROM ${OPEN_CONNECTOR_IMAGE}
COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start
ENTRYPOINT ["/usr/local/bin/railway-start"]
CMD []
