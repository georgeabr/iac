

### How to start up an instance of `Docmost` for notes and markdown
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
#### Configure the `docmost.service` to start at boot
Copy the `docmost.service` unit to `/etc/systemd/system/docmost.service`.
Enable with:
```bash
sudo systemctl enable docmost.service
```
Start with
```bash
sudo systemctl start docmost.service
```
Check status with
```bash
systemctl status docmost.service
```
#### Manage the containers
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
