#!/bin/bash
echo "listen_addresses = '*'" >> /etc/postgresql/18/main/postgresql.conf
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/18/main/pg_hba.conf
echo "host all all ::0/0 md5" >> /etc/postgresql/18/main/pg_hba.conf
service postgresql restart
service redis-server restart
su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='astro'\" | grep -q 1 || psql -c \"CREATE USER astro WITH SUPERUSER PASSWORD 'devpassword';\""
su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname='astro_dev'\" | grep -q 1 || psql -c \"CREATE DATABASE astro_dev OWNER astro;\""
echo "Postgres and Redis ready!"
