#!/bin/bash

set -e

if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< $PASSWORD_FILE)"
fi

# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${DB_NAME:='odoo'}

: ${ADMIN_PASS:='odoo'}
: ${LIST_DB:='False'}

# Definir variáveis de ambiente para URL e branch do repositório
: ${GIT_REPO_URL_MODULES:='https://github.com/sostrader/erp-modules.git'}
: ${GIT_REPO_BRANCH:='main'}

# Caminho para a pasta onde o repositório será clonado
ADDONS_DIR="/mnt/extra-addons"

# Clonar ou atualizar o repositório
if [ -d "$ADDONS_DIR/.git" ]; then
    echo "Atualizando o repositório existente em $ADDONS_DIR"
    git -C "$ADDONS_DIR" pull
else
    echo "Clonando o repositório em $ADDONS_DIR"
    git clone --branch "$GIT_REPO_BRANCH" "$GIT_REPO_URL_MODULES" "$ADDONS_DIR"
fi


#install python packages
pip3 install pip --upgrade
pip3 install -r /etc/odoo/requirements.txt

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"
check_config "db_name" "$DB_NAME"
check_config "admin_passwd" "$ADMIN_PASS"
check_config "list_db" "$LIST_DB"


case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py ${DB_ARGS[@]} --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1