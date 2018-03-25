#!/bin/sh

: ${DAVICAL_DB_HOST:=davical-db}
: ${DAVICAL_DB_NAME:=davical_db}
: ${DAVICAL_DB_PORT:=5432}
: ${DAVICAL_DBA_USER:=davical_dba}
: ${DAVICAL_DBA_PASSWORD:=davical_dba}
: ${DAVICAL_APP_USER:=davical_app}
: ${DAVICAL_APP_PASSWORD:=davical_app}
: ${DAVICAL_HOST:=davical}
: ${DAVICAL_PORT:=80}
: ${DAVICAL_SYSABBR:=davical}
: ${DAVICAL_ADMIN_EMAIL:="webaster@example.com"}
: ${DAVICAL_ADMIN_PASSWORD:="admin"}
: ${DAVICAL_SYSTEM_NAME:="The Davical Server"}

cat << EOF > /etc/davical/config.php
<?php
  \$c->domain_name = "${DAVICAL_HOST}";
  \$c->sysabbr     = '${DAVICAL_SYSABBR}';
  \$c->admin_email = '${DAVICAL_ADMIN_EMAIL}';
  \$c->system_name = "${DAVICAL_SYSTEM_NAME}";
  \$c->pg_connect[] = 'host=${DAVICAL_DB_HOST} dbname=${DAVICAL_DB_NAME} port=${DAVICAL_DB_PORT} user=${DAVICAL_APP_USER} password=${DAVICAL_APP_PASSWORD}';
EOF

sed -i \
    -e 's/@DAVICAL_DB_HOST@/'"${DAVICAL_DB_HOST}/g" \
    -e 's/@DAVICAL_DB_NAME@/'"${DAVICAL_DB_NAME}/g" \
    -e 's/@DAVICAL_DB_PORT@/'"${DAVICAL_DB_PORT}/g" \
    -e 's/@DAVICAL_DBA_USER@/'"${DAVICAL_DBA_USER}/g" \
    -e 's/@DAVICAL_DBA_PASSWORD@/'"${DAVICAL_DBA_PASSWORD}/g" \
    -e 's/@DAVICAL_APP_USER@/'"${DAVICAL_APP_USER}/g" \
    /etc/davical/administration.yml

sed -i \
    -e 's/@DAVICAL_PORT@/'"${DAVICAL_PORT}/g" \
    /etc/apache2/sites-enabled/000-davical.conf

cat << EOF > /root/.pgpass
${DAVICAL_DB_HOST}:*:*:${DAVICAL_DBA_USER}:${DAVICAL_DBA_PASSWORD}
${DAVICAL_DB_HOST}:*:*:${DAVICAL_APP_USER}:${DAVICAL_APP_PASSWORD}
EOF
chmod 0600 /root/.pgpass


OPTIONS=i::u::
LONGOPTIONS=initialize::,updatedb::
initdavical="false"
updatedb="true"

# -temporarily store output to be able to check for errors
# -e.g. use “--options” parameter by name to activate quoting/enhanced mode
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
if [ $? -ne 0 ]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -i|--initialize)
            case "$2" in
                "") initdavical=true ; shift 2 ;;
                *) initdavical=$2 ; echo $@ ; shift 2 ;;
            esac
            ;;
        -u|--updatedb)
            case "$2" in
                "") updatedb=true ; shift 2 ;;
                *) updatedb=$2 ; echo $@ ; shift 2 ;;
            esac
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error!"
            exit 3
            ;;
    esac
done

if [ ${initdavical} = true ];
then
    echo "running database setup scripts"
    psql -qXAt -U ${DAVICAL_DBA_USER} -h ${DAVICAL_DB_HOST} ${DAVICAL_DB_NAME} < /usr/share/awl/dba/awl-tables.sql 
    psql -qXAt -U ${DAVICAL_DBA_USER} -h ${DAVICAL_DB_HOST} ${DAVICAL_DB_NAME} < /usr/share/awl/dba/schema-management.sql
    psql -qXAt -U ${DAVICAL_DBA_USER} -h ${DAVICAL_DB_HOST} ${DAVICAL_DB_NAME} < /usr/share/davical/dba/davical.sql 
fi

if [ ${updatedb} = true ];
then
    echo "updating database"
    /usr/share/davical/dba/update-davical-database \
        --dbname ${DAVICAL_DB_NAME} \
        --dbuser ${DAVICAL_DBA_USER} \
        --dbhost ${DAVICAL_DB_HOST} \
        --dbpass ${DAVICAL_DBA_PASSWORD} \
        --appuser ${DAVICAL_APP_USER} \
        --nopatch --owner ${DAVICAL_DBA_USER}
fi

if [ ${initdavical} = true ];
then
    echo "finishing configuration"
    psql -qXAt -U ${DAVICAL_DBA_USER} -h ${DAVICAL_DB_HOST} ${DAVICAL_DB_NAME} \
         < /usr/share/davical/dba/base-data.sql 
    psql -qXAt -U ${DAVICAL_DBA_USER} -h ${DAVICAL_DB_HOST} \
         -c "UPDATE usr SET password = '**${DAVICAL_ADMIN_PASSWORD}' WHERE user_no = 1;" \
         ${DAVICAL_DB_NAME} 
fi

if [ "$1" = 'davical' ]; then
    . /etc/apache2/envvars && exec apachectl -D FOREGROUND
fi

exec "$@"
