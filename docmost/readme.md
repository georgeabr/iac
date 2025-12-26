

### How to configure and enable an instance of `Docmost` for notes and markdown
This guide will set up a `Docmost` docker instance running at system boot via a service, with data stored in `/srv/docmost/`
#### Configure `Docmost` Dockerfile
Create folder in home directory
```bash
mkdir ~/docmost; cd ~/docmost
```
Generate a random app secret
```bash
openssl rand -hex 32 > app-secret.txt
```
Copy the `docker-compose.yml` file in the `docmost` directory.  
Place the secret in the `docker-compose.yml` file, as `APP_SECRET`.  
Create a folder for the `docmost` storage and take ownership:
```bash
sudo mkdir -p /srv/docmost
sudo chown -R $USER:$USER /srv/docmost/
```
#### Configure the `Caddy` web server for the site
Copy configuration file to `/etc/caddy/Caddyfile`  
It configures the domain `docmost.georgetech.co.uk` as a public frontend to the service  
It also whitelists only a certain range of IP addresses
```bash
sudo systemctl restart caddy
```
Check the web server status
```bash
systemctl status caddy
```
#### Configure the `docmost.service` to start at boot
Copy the `docmost.service` unit to `/etc/systemd/system/docmost.service`  
Make sure to check the `WorkingDirectory` is absolute path to `~/docmost`  
Enable and start the service with
```bash
sudo systemctl enable --now docmost.service
```
Check status with
```bash
systemctl status docmost.service
```
#### Manage the containers
You must be in the `~/docmost` folder  
Manually start the docker containers  
```bash
docker compose up -d
```
Manually stop the containers
```bash
docker compose down
```
Check running containers and logs
```bash
docker ps
docker logs -f docmost
```
