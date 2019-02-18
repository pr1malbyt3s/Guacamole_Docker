# Guacamole_Docker
This project is meant to automatically install and setup the Guacamole service as three separate Docker containers on a Debian server. It uses PostgreSQL as the database container alongside the Guacamole and Guacd containers. It only exposes port 8080 locally (127.0.0.1) as it is meant to be served behind a reverse proxy. Enjoy!
