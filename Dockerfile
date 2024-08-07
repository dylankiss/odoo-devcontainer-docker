# syntax=docker/dockerfile:1
FROM ubuntu:noble
ENV LANG=C.UTF-8

ARG ODOO_VERSION=master

# Copy scripts and executables
COPY --chmod=555 scripts/* /tmp/scripts/
COPY --chmod=555 bin/* /usr/local/bin/

# Add odoo dependencies file from odoo/debian/control
ADD "https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/debian/control" /tmp/control.txt

# Add Python dependencies file for the documentation build
ADD "https://raw.githubusercontent.com/odoo/documentation/${ODOO_VERSION}/requirements.txt" /tmp/doc_requirements.txt

# Add Python dependencies file for the odoo build
ADD "https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt" /tmp/requirements.txt

# Add flamegraph
ADD https://raw.githubusercontent.com/brendangregg/FlameGraph/master/flamegraph.pl /usr/local/bin/flamegraph.pl

# Add GeoIP databases
ADD https://github.com/maxmind/MaxMind-DB/raw/main/test-data/GeoIP2-City-Test.mmdb /usr/share/GeoIP/GeoLite2-City.mmdb
ADD https://github.com/maxmind/MaxMind-DB/raw/main/test-data/GeoIP2-Country-Test.mmdb /usr/share/GeoIP/GeoLite2-Country.mmdb

# Setup the container with all dependencies
RUN ./tmp/scripts/odoo-dev-container-setup.sh

# Extra setup when running the container standalone

EXPOSE 8069

USER odoo

ENTRYPOINT [ "/bin/zsh" ]
