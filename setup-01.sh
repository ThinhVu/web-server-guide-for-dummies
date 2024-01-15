apt update

apt install nginx

apt install snapd
snap install core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-route53

snap install docker
