#!/bin/bash

set -eux

export DEBIAN_FRONTEND=noninteractive
ODOO_USER=odoo
group_name="${ODOO_USER}"
user_home="/home/${ODOO_USER}"

# *****************************************************************************
# ** Debian packages installation                                            **
# *****************************************************************************

# Install all necessary and useful Debian packages
apt-get update
apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    file \
    flake8 \
    fonts-freefont-ttf \
    fonts-noto-cjk \
    gawk \
    git \
    gnupg \
    gsfonts \
    libldap2-dev \
    libjpeg9-dev \
    libpq-dev \
    libsasl2-dev \
    libxslt1-dev \
    lsb-release \
    nano \
    npm \
    ocrmypdf \
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
    python3-websocket \
    python3-wheel \
    python3-xmlsec \
    sed \
    ssh \
    sudo \
    unzip \
    vim \
    xfonts-75dpi \
    zip \
    zlib1g-dev \
    zsh

# Install Debian packages listed in odoo/debian/control
sed -n '/^Depends:/,/^[A-Z]/p; /^Recommends:/,/^[A-Z]/p' /tmp/control.txt \
    | awk '/^ [a-z]/ { gsub(/,/,"") ; print $1 }' \
    | sort -u \
    | xargs apt-get install -y -qq
rm /tmp/control.txt

# Install wkhtmltox using the correct architecture
TARGETARCH="$(dpkg --print-architecture)"
curl -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${TARGETARCH}.deb -o /tmp/wkhtmltox.deb
apt-get install -y --no-install-recommends --fix-missing -qq /tmp/wkhtmltox.deb
rm /tmp/wkhtmltox.deb

# Get the latest version of all packages and clean up
apt-get upgrade -y --no-install-recommends
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*


# *****************************************************************************
# ** User and system settings                                                **
# *****************************************************************************

# Remove the default "ubuntu" user
userdel -f -r ubuntu

# Add an Odoo user and give him sudo rights
useradd -s /bin/bash -m $ODOO_USER
passwd -d $ODOO_USER
echo $ODOO_USER ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$ODOO_USER
chmod 0440 /etc/sudoers.d/$ODOO_USER

# Restore user .bashrc / .profile / .zshrc defaults from skeleton file if it doesn't exist or is empty
possible_rc_files=(".bashrc" ".profile" ".zshrc" ".zprofile")
for rc_file in "${possible_rc_files[@]}"; do
    if [ -f "/etc/skel/${rc_file}" ]; then
        if [ ! -e "${user_home}/${rc_file}" ] || [ ! -s "${user_home}/${rc_file}" ]; then
            cp "/etc/skel/${rc_file}" "${user_home}/${rc_file}"
            chown ${ODOO_USER}:${group_name} "${user_home}/${rc_file}"
        fi
    fi
done

# Add RC snippet and custom bash prompt
cat /tmp/scripts/rc_snippet.sh >> /etc/bash.bashrc
cat /tmp/scripts/bash_theme_snippet.sh >> "${user_home}/.bashrc"
cat /tmp/scripts/bash_theme_snippet.sh >> "/root/.bashrc"
chown ${ODOO_USER}:${group_name} "${user_home}/.bashrc"

# Configure zsh and Oh My Zsh!
cat /tmp/scripts/rc_snippet.sh >> /etc/zsh/zshrc
chsh --shell /bin/zsh ${ODOO_USER}

user_rc_file="${user_home}/.zshrc"
oh_my_install_dir="${user_home}/.oh-my-zsh"
template_path="${oh_my_install_dir}/templates/zshrc.zsh-template"
if [ ! -d "${oh_my_install_dir}" ]; then
    umask g-w,o-w
    mkdir -p ${oh_my_install_dir}
    git clone --depth=1 \
        -c core.eol=lf \
        -c core.autocrlf=false \
        -c fsck.zeroPaddedFilemode=ignore \
        -c fetch.fsck.zeroPaddedFilemode=ignore \
        -c receive.fsck.zeroPaddedFilemode=ignore \
        "https://github.com/ohmyzsh/ohmyzsh" "${oh_my_install_dir}" 2>&1

    # Shrink git while still enabling updates
    cd "${oh_my_install_dir}"
    git repack -a -d -f --depth=1 --window=1
fi

# Add Dev Containers theme
mkdir -p ${oh_my_install_dir}/custom/themes
cp -f /tmp/scripts/devcontainers.zsh-theme "${oh_my_install_dir}/custom/themes/devcontainers.zsh-theme"
ln -sf "${oh_my_install_dir}/custom/themes/devcontainers.zsh-theme" "${oh_my_install_dir}/custom/themes/codespaces.zsh-theme"

# Add devcontainer .zshrc template
echo -e "$(cat "${template_path}")\nDISABLE_AUTO_UPDATE=true\nDISABLE_UPDATE_PROMPT=true" > ${user_rc_file}
sed -i -e 's/ZSH_THEME=.*/ZSH_THEME="devcontainers"/g' ${user_rc_file}

# Copy to Odoo user
copy_to_user_files=("${oh_my_install_dir}")
[ -f "$user_rc_file" ] && copy_to_user_files+=("$user_rc_file")
cp -rf "${copy_to_user_files[@]}" /root
chown -R ${ODOO_USER}:${group_name} "${copy_to_user_files[@]}"

# Ensure config directory
user_config_dir="${user_home}/.config"
if [ ! -d "${user_config_dir}" ]; then
    mkdir -p "${user_config_dir}"
    chown ${ODOO_USER}:${group_name} "${user_config_dir}"
fi

# Register Odoo user as a postgres user with "Create DB" role attribute
service postgresql start
sudo -u postgres createuser -d $ODOO_USER


# *****************************************************************************
# ** Python packages installation                                            **
# *****************************************************************************

# Install as Odoo user
su - $ODOO_USER

export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_IGNORE_INSTALLED=1

python3 -m pip install --upgrade pip

python3 -m pip install --no-cache-dir \
    ebaysdk==2.1.5 \
    pdf417gen==0.7.1 \
    ruff==0.4.7

# Install Python dependencies for the documentation and odoo builds
python3 -m pip install --no-cache-dir -r /tmp/doc_requirements.txt
python3 -m pip install --no-cache-dir -r /tmp/requirements.txt

rm /tmp/doc_requirements.txt
rm /tmp/requirements.txt

export PIP_IGNORE_INSTALLED=0

# Switch back to root user
exit


# *****************************************************************************
# ** Node modules installation                                               **
# *****************************************************************************

export NODE_PATH=/usr/lib/node_modules/
export npm_config_prefix=/usr
npm install --force -g \
    rtlcss@3.4.0 \
    es-check@6.0.0 \
    eslint@8.1.0 \
    prettier@2.7.1 \
    eslint-config-prettier@8.5.0 \
    eslint-plugin-prettier@4.2.1


# *****************************************************************************
# ** Final configuration                                                     **
# *****************************************************************************

# Make flamegraph executable
chmod +rx /usr/local/bin/flamegraph.pl

rm -rf /tmp/scripts
