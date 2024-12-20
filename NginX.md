# nginx-config
Nginx is very easy to work with. There are a few configurations you may need to know.


## Simple proxy server
Suppose you're running the app in your VPS and listening on port 6000. ATM, you can access to the app at http://{vps-ip-address}:6000

But everyone love visit the web via domain name rather than IP address & port. So we need to add a Nginx config to resolve domain name & forward the request to your app.

For example: I created a domain name "tvux.me" and pointing it to my VPS server (A record).

In VPS, create a Nginx configuration file, using domain name for naming is recommended
`sudo vi /etc/nginx/sites-enabled/tvux.me`

**/etc/nginx/sites-enabled/tvux.me**
```
server {
   server_name tvux.me;
   listen 80;
   location / {
      proxy_pass http://localhost:6000;
   }
}
```
Now I can access my web app at http://tvux.me

## Https server
To enable HTTPS for Nginx, install certbot & certbot Nginx plugin (tutorial [Web-server-for-dummies](https://github.com/ThinhVu/web-server-guide-for-dummies))
```
sudo certbot --nginx
```
then select config file you want to make a HTTPS. In this example it's **tvux.me**, then select option 2 to redirect all HTTP request to HTTPS.

Now I can access my web app at https://tvux.me

## IPv6 support

To support IPv6, the first thing is config the domain name to poiting to my server with AAAA record

Then in my server, modify the config file a little bit.
**/etc/nginx/sites-enabled/tvux.me**
```
server {
   server_name tvux.me;
   listen 80;
   listent [::]:80;
   location / {
      proxy_pass http://localhost:6000;
   }
}
```

## Load balancer
Your app might need to update sometimes in the future so to ensure the app uptime 100%, you may need to run at least 1 backup instance. For example, I run the same app in port 6001 for backup purpose.

**/etc/nginx/sites-enabled/tvux.me**
```
upstream backend {
  server localhost:6000 fail_timeout=5s max_fails=3;
  server localhost:6001 backup;
}

server {
   server_name tvux.me;
   listen 80;
   listent [::]:80;
   location / {
      proxy_pass http://backend;
   }
}
```

### Connection consistent

```
upstream backend {
 hash $binary_remote_addr consistent;
 server localhost:5000;
 server localhost:5001;
 server localhost:5002;
}
```

## Inspect request IP address
**/etc/nginx/sites-enabled/tvux.me**
```
server {
   server_name tvux.me;
   listen 80;

   location / {
      proxy_pass http://backend;
      proxy_set_header X-Real-IP  $remote_addr;
      proxy_set_header X-Forwarded-For $remote_addr;
      proxy_set_header Host $host;
   }
}
```
Now you can get the request IP address from `request.headers['X-Real-IP']`

## CORS
**/etc/nginx/sites-enabled/tvux.me**
```
server {
   server_name tvux.me;
   listen 80;

   location / {
      proxy_pass http://backend;
      proxy_http_version 1.1;
      add_header Access-Control-Allow-Origin *;
      add_header Access-Control-Allow-Headers *;
      proxy_set_header Host $host;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $connection_upgrade;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   }
}
```

## Worker connections
By default, Nginx uses 768 worker_connections. It'll fail to serve your app if there is a massive amount of requests at the same time. A simple solution is increase worker_connections to a larger number.

**/etc/nginx/nginx.conf**
```
events {
    worker_connections 20000;
}
```

## Increase maximum request body size
By default, Nginx uses 10M for maximum body size (request's body).
**/etc/nginx/nginx.conf**
```
http {
   client_max_body_size 300M;
}
```

## Read access log
```
cat /var/log/nginx/access.log
```

## Read error log
```
cat /var/log/nginx/error.log
```
