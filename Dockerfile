# Ubuntu 24.04 LTS (Noble Numbat)
FROM ubuntu:noble

# Set the most standard locale
ENV LANG=C.UTF-8

# Run the following commands as root
USER root

# Add flamegraph
ADD --chmod=555 https://raw.githubusercontent.com/brendangregg/FlameGraph/master/flamegraph.pl /usr/local/bin/flamegraph.pl

# Add GeoIP databases
ADD https://github.com/maxmind/MaxMind-DB/raw/main/test-data/GeoIP2-City-Test.mmdb /usr/share/GeoIP/GeoLite2-City.mmdb
ADD https://github.com/maxmind/MaxMind-DB/raw/main/test-data/GeoIP2-Country-Test.mmdb /usr/share/GeoIP/GeoLite2-Country.mmdb

# Install Debian packages
RUN set -x; \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        build-essential \
        ca-certificates \
        chromium \
        curl \
        file \
        fonts-freefont-ttf \
        fonts-noto-cjk \
        gawk \
        git \
        gnupg \
        gsfonts \
        libldap2-dev \
        libjpeg9-dev \
        libsasl2-dev \
        libxslt1-dev \
        lsb-release \
        nano \
        npm \
        ocrmypdf \
        sed \
        sudo \
        unzip \
        vim \
        xfonts-75dpi \
        zip \
        zlib1g-dev \
        zsh && \
    rm -rf /var/lib/apt/lists/*

# Remove the default Ubuntu user, add an Odoo user and give him sudo rights
RUN userdel -f -r ubuntu && \
    groupadd -g 10000 odoo && \
    useradd --create-home -u 10000 -g odoo -G audio,video odoo && \
    passwd -d odoo && \
    echo odoo ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/odoo && \
    chmod 0440 /etc/sudoers.d/odoo

# Create the working directory and make it owned by the Odoo user
RUN mkdir /workspaces && \
    chown odoo /workspaces

# Install Python-related Debian packages
RUN set -x; \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        flake8 \
        libpq-dev \
        publicsuffix \
        pylint \
        python3 \
        python3-asn1crypto \
        python3-dbfread \
        python3-dev \
        python3-gevent \
        python3-google-auth \
        python3-html2text \
        python3-jwt \
        python3-markdown \
        python3-mock \
        python3-phonenumbers \
        python3-pip \
        python3-setuptools \
        python3-suds \
        python3-watchdog \
        python3-websocket \
        python3-wheel \
        python3-xmlsec && \
    rm -rf /var/lib/apt/lists/*

# Install wkhtmltox using the correct architecture
RUN TARGETARCH="$(dpkg --print-architecture)"; \
    curl -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${TARGETARCH}.deb -o /tmp/wkhtmltox.deb && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --fix-missing -qq \
        /tmp/wkhtmltox.deb && \
    rm -rf /var/lib/apt/lists/* && \
    rm /tmp/wkhtmltox.deb

# Install Node modules
ENV NODE_PATH=/usr/lib/node_modules/
ENV npm_config_prefix=/usr
RUN npm install --force -g \
        rtlcss@3.4.0 \
        es-check@6.0.0 \
        eslint@8.1.0 \
        prettier@2.7.1 \
        eslint-config-prettier@8.5.0 \
        eslint-plugin-prettier@4.2.1

# Install Debian packages listed in odoo/debian/control
ARG ODOO_VERSION=master
ADD https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/debian/control /tmp/control.txt
RUN apt-get update && \
    sed -n '/^Depends:/,/^[A-Z]/p' /tmp/control.txt \
        | awk '/^ [a-z]/ { gsub(/,/,"") ; gsub(" ", "") ; print $NF }' \
        | sort -u \
        | DEBIAN_FRONTEND=noninteractive xargs apt-get install -y -qq --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm /tmp/control.txt


# Configure zsh and Oh My Zsh!
RUN --mount=type=bind,target=/tmp/custom.zshrc,source=custom.zshrc \
    umask g-w,o-w && \
    mkdir -p /home/odoo/.oh-my-zsh && \
    git clone --depth=1 \
        -c core.eol=lf \
        -c core.autocrlf=false \
        -c fsck.zeroPaddedFilemode=ignore \
        -c fetch.fsck.zeroPaddedFilemode=ignore \
        -c receive.fsck.zeroPaddedFilemode=ignore \
        "https://github.com/ohmyzsh/ohmyzsh" "/home/odoo/.oh-my-zsh" 2>&1 && \
    cd /home/odoo/.oh-my-zsh && \
    git repack -a -d -f --depth=1 --window=1 && \
    cat /home/odoo/.oh-my-zsh/templates/zshrc.zsh-template > /home/odoo/.zshrc && \
    echo "\nDISABLE_AUTO_UPDATE=true\nDISABLE_UPDATE_PROMPT=true\n" >> /home/odoo/.zshrc && \
    cat /tmp/custom.zshrc >> /home/odoo/.zshrc && \
    chown -R odoo /home/odoo/.oh-my-zsh && \
    chsh --shell /bin/zsh odoo

# Switch to Odoo user
USER odoo

# Needed to install requirements outside a venv
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

# Install pip requirements
RUN python3 -m pip install --no-cache-dir \
        ebaysdk==2.1.5 \
        pdf417gen==0.7.1 \
        ruff==0.4.7

ARG ODOO_VERSION=master
ADD --chown=odoo https://raw.githubusercontent.com/odoo/documentation/${ODOO_VERSION}/requirements.txt /tmp/doc_requirements.txt
ADD --chown=odoo https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /tmp/doc_requirements.txt && \
    python3 -m pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt && \
    rm /tmp/doc_requirements.txt

# Add odoo-i18n-tools
WORKDIR "/home/odoo"
RUN git clone https://github.com/dylankiss/odoo-i18n-tools.git

# Expose Odoo services
EXPOSE 8069 8071 8072 8073

CMD [ "zsh" ]
