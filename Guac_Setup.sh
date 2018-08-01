#!/bin/bash

docker stop guacd > /dev/null 2>&1
sleep 5
docker stop guacamole > /dev/null 2>&1
sleep 5
docker stop guac-postgres > /dev/null 2>&1
sleep 5
docker rm guacd > /dev/null 2>&1
docker rm guacamole > /dev/null 2>&1
docker rm guac-postgres > /dev/null 2>&1

echo "Building PostgreSQL database file."
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > initdb.sql

while true
do
        read -p 'Enter Guacamole Username: ' guacuser
        echo
        read -sp 'Enter Guacamole Password: ' guacpass1
        echo
        read -sp 'Please Enter Password Again: ' guacpass2
        echo
        [ "$guacpass1" = "$guacpass2" ] && break
        echo 'Passwords do not match. Please try again.'
        echo
done
guacpass="'$guacpass1'"
echo "Starting guac-postgres container."
docker run --name guac-postgres -d postgres
echo "Waiting for guac-postgres to start."
sleep 3

docker cp initdb.sql guac-postgres:/guac_db.sql
docker exec -it guac-postgres createdb guacamole_db -U postgres

echo "Creating guacamole_db schema."

docker exec -it guac-postgres bash -c "cat guac_db.sql | psql -d guacamole_db -U postgres -f -"

echo "Creating database file for user $guacuser."
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "CREATE USER $guacuser WITH PASSWORD $guacpass;"
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO $guacuser;"
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA public TO $guacuser;"

#docker cp guac_setup.sql guac-postgres:/guac_setup.sql

#echo "Creating $guacuser in guacamole_db."
#docker exec -it guac-postgres bash -c "cat guac_setup.sql | psql -d guacamole_db -U postgres"

echo "Starting guacd."
docker run --name guacd --restart=always -d guacamole/guacd

echo "Starting guacamole."
docker run --name guacamole --link guacd:guacd --link guac-postgres:postgres \
-e POSTGRES_DATABASE=guacamole_db \
-e POSTGRES_USER=$guacuser \
-e POSTGRES_PASSWORD=$guacpass \
--restart=always -d -p 8080:8080 guacamole/guacamole
