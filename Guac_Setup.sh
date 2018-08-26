#Script that installs Guacamole as Docker containers.
#Uses postgres, guacamole/guacamole, and guacamole/guacd Docker images.
#Works for Debian 9.

#!/bin/bash

#Set color variables.
RED='\033[0;31m'
NC='\033[0m'

#Install docker:
echo -e "${RED}Installing Docker${NC}"
apt-get update
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt-get update
apt-cache policy docker-ce
apt-get install -y docker-ce
systemctl enable docker

#Pull docker images:
echo -e "${RED}Pulling Docker Images Needed${NC}"
docker pull guacamole/guacd
docker pull guacamole/guacamole
docker pull postgres

#Start Guacamole installation.
echo -e "${RED}Starting Guacamole Installation${NC}"
#Stop any containers that are running under the same name as ones that will be initialized.
echo -e "${RED}Stopping Any Redundant Containers${NC}"
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
echo -e "${RED}Building PostgreSQL Database File${NC}"
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > initdb.sql

#Get input for username and password that will be used by Guacamole to connect to database.
echo -e "${RED}Please Follow Credentials Prompt To Finish Database Setup${NC}"
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
echo -e "${RED}Starting guac-postgres Container${NC}"
docker run --name guac-postgres -d postgres
echo -e "${RED}Waiting For guac-postgres To Start${NC}"
sleep 3
echo -e "${RED}guac-postgres Container Started${NC}"
docker cp initdb.sql guac-postgres:/guac_db.sql
echo -e "${RED}Creating guacamole_db Database${NC}"
docker exec -it guac-postgres createdb guacamole_db -U postgres
echo -e "${RED}Creating guacamole_db Schema${NC}"
docker exec -it guac-postgres bash -c "cat guac_db.sql | psql -d guacamole_db -U postgres -f -"
echo -e "${RED}Creating Database File For User $guacuser${NC}"
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "CREATE USER $guacuser WITH PASSWORD $guacpass;"
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO $guacuser;"
docker exec -it guac-postgres psql -d guacamole_db -U postgres -c "GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA public TO $guacuser;"
echo -e "${RED}guac-postgres Setup Complete${NC}"

#Initialize guacd container.
echo -e "${RED}Starting guacd Container${NC}"
docker run --name guacd --restart=always -d guacamole/guacd
echo -e "${RED}guacd Container Started${NC}"

#Initialize guacamole container.
echo -e "${RED}Starting guacamole Container${NC}"
docker run --name guacamole --link guacd:guacd --link guac-postgres:postgres \
-e POSTGRES_DATABASE=guacamole_db \
-e POSTGRES_USER=$guacuser \
-e POSTGRES_PASSWORD=$guacpass \
--restart=always -d -p 127.0.0.1:8080:8080 guacamole/guacamole
echo -e "${RED}guacamole Container Started${NC}"

#Installation complete.
echo -e "${RED}Installation Complete. Enjoy!${NC}"
