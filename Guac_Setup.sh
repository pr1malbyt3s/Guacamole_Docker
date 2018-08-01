#Script that installs Guacamole as Docker containers.
#Uses postgres, guacamole/guacamole, and guacamole/guacd Docker images.
#Works for Debian 9.

#!/bin/bash

echo "Starting Guacamole installation."
#Stop any containers that are running under the same name as ones that will be initialized.
echo "Stopping any redundant containers."
docker stop guacd > /dev/null 2>&1
sleep 2
docker stop guacamole > /dev/null 2>&1
sleep 2
docker stop guac-postgres > /dev/null 2>&1
sleep 2
docker rm guacd > /dev/null 2>&1
docker rm guacamole > /dev/null 2>&1
docker rm guac-postgres > /dev/null 2>&1

#Create PostgreSQL database file.
echo "Building PostgreSQL database file."
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > initdb.sql

#Get input for username and password that will be used by Guacamole to connect to database.
while true
do
        read -p 'Enter Guacamole Database Username: ' guacuser
        echo
        read -sp 'Enter Guacamole Database Password: ' guacpass1
        echo
        read -sp 'Please Enter Guacamole Database Password Again: ' guacpass2
        echo
        [ "$guacpass1" = "$guacpass2" ] && break
        echo 'Passwords do not match. Please try again.'
        echo
done

#Copy database password supplied by user to new variable with correct format.
guacpass="'$guacpass1'"

#Setup and initialize guac-postgres container.
echo "Starting guac-postgres container."
docker run --name guac-postgres -d postgres
echo "Waiting for guac-postgres to start."
sleep 3
echo "guac-postgres container started."
docker cp initdb.sql guac-postgres:/guac_db.sql
echo "Creating guacamole_db database."
docker exec -it guac-postgres createdb guacamole_db -U postgres
echo "Creating guacamole_db schema."
docker exec -it guac-postgres bash -c "cat guac_db.sql | psql -d guacamole_db -U postgres -f -"
echo "Creating database file for user $guacuser."
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "CREATE USER $guacuser WITH PASSWORD $guacpass;"
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO $guacuser;"
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA public TO $guacuser;"
echo "guac-postgres setup complete."

#Initialize guacd container.
echo "Starting guacd container."
docker run --name guacd --restart=always -d guacamole/guacd
echo "guacd container started."

#Initialize guacamole container.
echo "Starting guacamole container."
docker run --name guacamole --link guacd:guacd --link guac-postgres:postgres \
-e POSTGRES_DATABASE=guacamole_db \
-e POSTGRES_USER=$guacuser \
-e POSTGRES_PASSWORD=$guacpass \
--restart=always -d -p 127.0.0.1:8080:8080 guacamole/guacamole
echo "Gucamole container started."
