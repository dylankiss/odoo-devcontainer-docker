# Odoo Development Container

This repository contains all files necessary to build a Docker image for Odoo development.

It is based on the [Ubuntu 24.04 (Noble Numbat)](https://hub.docker.com/_/ubuntu) Docker image and the configuration is based on Odoo's Runbot Docker image and part of the [`common-utils` feature](https://github.com/devcontainers/features/tree/main/src/common-utils).

In short it does the following:
- Install all necessary Debian packages to develop and run Odoo (including Python and PostgreSQL).
- Install the right version of [`wkhtmltox`](https://github.com/wkhtmltopdf/packaging/releases).
- Configure the system with an `odoo` user and give the user access to PostgreSQL.
- Install `zsh` as default shell and [Oh My Zsh!](https://ohmyz.sh/) with a custom [`devcontainers` theme](https://github.com/devcontainers/features/blob/main/src/common-utils/scripts/devcontainers.zsh-theme) taken from the `common-utils` feature.
- Install all Python dependencies, with most of them from the latest [`odoo`](https://github.com/odoo/odoo) and [`documentation`](https://github.com/odoo/documentation) repositories' `requirements.txt` files.
- Install the necessary `node` modules.
- Install [`flamegraph`](https://github.com/brendangregg/FlameGraph).

## Usage

First you need to pull the Docker image like this:

```sh
docker pull dylankiss/odoo-devcontainer
```

Assume your directory structure looks like this:

```
odoo-dev
├── 17.0
│   ├── design-themes (17.0)
│   ├── documentation (17.0)
│   ├── enterprise (17.0)
│   ├── internal (symlink to ../internal)
│   ├── odoo (17.0)
│   ├── upgrade (symlink to ../upgrade)
│   └── upgrade-util (symlink to ../upgrade-util)
│
├── internal (master)
├── upgrade (master)
└── upgrade-util (master)
```

You can run a working container will all necessary mounted volumes by invoking this command from the `odoo-dev` directory:

```sh
docker run -v ./17.0:/workspaces/17.0 \
           -v ./internal:/workspaces/internal \
           -v ./upgrade:/workspaces/upgrade \
           -v ./upgrade-util:/workspaces/upgrade-util \
           -w /workspaces/17.0 \
           -p 8069:8069 \
           -i -t dylankiss/odoo-devcontainer
```
> [!NOTE]
> The first four lines map the folders on our host system to a folder in the container so they will live update. The next two line set the default workspace folder and expose the default Odoo port 8069 to the host system.

Once the container is launched, the terminal will run as the `odoo` user in the `/workspaces/17.0` directory in your container. To start developing, start the `postgres` service and launch Odoo as you normally would, using e.g.

```sh
# Start the PostgreSQL server
sudo service postgresql start

# Run Odoo
./odoo/odoo-bin --addons-path=./enterprise,./odoo/addons -d your-database -i base
```

After this, you can access your Odoo instance as usual via `http://localhost:8069`.

## Good to Know

The image is built for both `amd64` as well as `arm64` chipsets (like the Apple Silicon chips).
