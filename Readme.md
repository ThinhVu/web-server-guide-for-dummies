# Setup WebServer guide for dummies

## Requirement

```
OS: >= Debian 10
RAM: >= 1GB
Storage: >= 10GB
```

Why Debian?

- It Linux distro. It's free, lightweight enough.
- It's just a matter of choice.
- Nothing more.

Why 1GB RAM? It's even less memory than my stupid phone.
- It's enough to run a lot of things, and enough to build things too. Remember? With 4KB of RAM, people can send someone to the moon.

Why 10GB storage? It's less storage than my stupid phone.
- Yes. But it's the minimum storage option for almost VPS service provider nowadays. With this, we can install applications, install another stuff, and the database too.

With these requirements, you may need to pay about $6 - 8$/month for purchasing the service. You can use it for learning purpose or even for production too. If you using the VPS for short time, considering using some cloud VPS which cost you by the hours of usage (Digital Ocean, Vultr, AWS EC2 etc, ...)

## Setup

### Connecting to the server

After setting up the server, you can connect to it using SSH (Secure Shell).

Don't scare about it. Just using `ssh {username}@{ip_of_your_server}` then enter the password and done. <br/> Now you have access to remote terminal, using it just like the one (Terminal or Cmd prompt) in your machine.

*{username} & {ip_of_your_server} will be provided by VPS provider. Usually via an email which you used to rent the VPS.*
 


### Setup Nginx web server

Why Nginx (engine-x)?

These are a few web server application (Apache, IIS, ..., Nginx). The last one is trending right now. So we'll use it. 

Run cmd below to install Nginx (ref: [Install Nginx on debian 10](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-debian-10))
```
sudo apt install nginx
```

You may need to run the cmdline with `sudo` if the VPS provider doesn't give you the root account.

### Setup Certbot to generate SSL, TLS certificate automatically and FREE

Why SSL, TLS certificates?

For better secure for our users. Everyone loves https nowadays, so why not?

Follow instruction in this website to install latest certbot:

https://certbot.eff.org/instructions

```
apt install snapd
snap install core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
```

Now we have a server, Nginx & Certbot installed. It's the time to buy a domain name.

### Buying a domain name

It's very easy to buy a domain, you can choose any domain name providers out there (AWS Route 53, Namecheap, GoDaddy ..., you name it).

There are some features you need to care when choosing domain name provider:
- Whether it support payment via Paypal, Square, Stripe, ... (in case you have some issues with Credit, Debit card)
- Whether this service allow you to sub-domain.
- Whether set up sub-domain easily.
- Support robust routing mechanisms (base on geography, weighted,...)
- Have support center

Recommended:
- [GoDaddy](https://godaddy.com)
- [Namecheap](https://www.namecheap.com/)
- [Aws Route 53](https://aws.amazon.com/vi/route53/)
- You name it

### Setup domain, sub-domain
It's quite simply, you just need to point your domain name to the server machine public IP address and done.

In this example below, I create a imagine domain name `my-site.com` and sub-domain `admin.my-site.com`, `api.my-site.com`, `docker-registry.my-site.com`, `mongo.my-site.com` and point all domain to my VPS with public ip address is `51.79.xxx.76`.
![Namecheap Setting Domain](./assets/images/setting-domain-name.png)

Now if you access these domains, I bet you'll see Nginx Welcome page (in your imagination). Just leave it for now, we'll touch it later after complete setting up our applications.

### Setup Docker

Why Docker? WTF! Why people never stop talking about it nowadays. Do we actually need it?

Absolutely not.<br/>
We don't need Docker to run things<br/>
and we don't need DNS to resolve our domains<br/>
and we don't event need web servers (Nginx, Apache, IIS) to mapping a domain to specified service in our service<br/>
and we don't even need a domain name at all<br/>
...<br/>
just public IP address and port is enough.

But without this stuff, internet is sucks and using it will be very difficult.<br/>
That why people create thing to make it better.

Virtual Machine, Docker, Docker Swarm, Kubernetes, Jenkins, Circle CI, ... all of these stuff help the deployment process smoothly, easier. That why we all spent time to learn it. 

Docker help you run your apps in containerized environment which is separated from your server machine, but can sharing the same resources (RAM, shared storage).

To install Docker for debian, run cmd below (ref: [Install docker for Debian in detail](https://docs.docker.com/engine/install/debian/)):
```
# allow apt to use a repository over HTTPS
sudo snap install docker
```

### Setup Private Docker Registry

You can host your docker image at docker hub - which is public for everyone. But in case if you want to keep your docker image privately, there are 2 options you should consider. One is using a service like AWS ECR, the other is self hosting. The following guide help you hosting your our private registry.

The cmd below will create basic authentication from {username} and {password} and store it in **registry-config/htpasswd** file - which will be used as Docker private registry user. Note that, you must replace {username} and {password} with the account you want to access the private registry.
```
docker pull httpd:2

mkdir registry-config

docker run --entrypoint htpasswd httpd:2 -Bbn {username} {password} > registry-config/htpasswd
```

Example: Create account with username = dev, password = 123456, store generated hash in registry-config/htpasswd file.

```
docker pull httpd:2

mkdir registry-config

docker run --entrypoint htpasswd httpd:2 -Bbn dev 123456 > registry-config/htpasswd
```

Troubleshoot:

If you don't have root access, running this command may be fail because httpd:2 can not access permission to **registry-config/htpasswd** file.
In this case, you just need to run `docker run --entrypoint htpasswd httpd:2 -Bbn {username} {password}`, copy the output to **registry-config/htpasswd** file.


#### Create Docker registry config file (ref: [Example](https://github.com/Joxit/docker-registry-ui/blob/main/examples/ui-as-proxy/registry-config/credentials.yml))
```
vi registry-config/credentials.yml
```

Credentials.yml content:<br/>

*Note that `headers` section is optional. You can remove `headers` section if you only want to work with docker registry via terminal. If you want to use it in web interface (we'll install it later), you must replace {docker-registry-ui-domain-name} with the domain name of UI app. For example: `https://registry.my-site.com`*

```yml
version: 0.1
log:
  fields:
    service: registry
storage:
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['{docker-registry-ui-domain-name}']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
auth:
  htpasswd:
    realm: basic-realm
    path: /etc/docker/registry/htpasswd
```

Now the account & setting for Docker private registry has been created. We're going to run it via docker container.
```
docker run -d -p 5000:5000 --restart=always \
  --name registry  \
  -v "$(pwd)"/data:/var/lib/registry \
  -v "$(pwd)"/auth:/auth \
  -v "$(pwd)"/registry-config/credentials.yml:/etc/docker/registry/config.yml \
  -v "$(pwd)"/registry-config/htpasswd:/etc/docker/registry/htpasswd \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
registry:2 
```

### Setup Docker Registry UI

[Recommended] I already hosted a docker registry UI app at https://docker.vuxify.com, you can use this app to control your docker repositories and skip steps below.

---

But if you still want to do it by yourself, here the instructions:

1. Using my docker registry UI: https://hub.docker.com/repository/docker/dockerer123456/dru/general

<details>
 <summary>2. Using joxit's docker registry UI: https://hub.docker.com/r/joxit/docker-registry-ui</summary>
 
 Note that you must replace {docker-registry-url} with the url of your docker registry, and {PORT_TO_DOCKER_REGISTRY_UI} to the port you want this service to listen.

```
sudo docker run -d  -p {PORT_TO_DOCKER_REGISTRY_UI}:80 --restart=always \
   --name registry-ui \
   -e DELETE_IMAGES=true \
   -e REGISTRY_TITLE=DockerRegistry \
   -e REGISTRY_URL={docker-registry-url} \
   joxit/docker-registry-ui:latest
```

Example:

Hosting docker-registry container in port 5000, access by `https://registry.my-site.com`. Then hosting docker-registry-ui container in port 5001, access by `https://ui-registry.my-site.com`.

In registry-config/credentials.yml file:
```yml
...
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['https://ui-registry.my-site.com']
...
```

And commandline to run docker registry ui:
```
sudo docker run -d  -p 5001:80 --restart=always \
   --name registry-ui \
   -e DELETE_IMAGES=true \
   -e REGISTRY_TITLE=DockerRegistry \
   -e REGISTRY_URL=https://registry.my-site.com \
   joxit/docker-registry-ui:latest
```
</details>

### Build Docker Images from your machine

To build docker image, we need to create Dockerfile. See docker file reference ([Docker file](https://docs.docker.com/engine/reference/builder/))

```
docker build -t {registry-domain}/{image-name}:{version} {working-dir-aka-docker-context}
```

Example: Build docker image with a name *registry.my-site.com/my-app*, version (aka tag) *1.0.0* in current working directory (define by dot symbol ".") 

```
docker build -t registry.my-site.com/my-app:1.0.0 .
```

### Publish Docker Images to Private Docker Registry

Now you already have an image, it's time to push it to our private registry.
```
docker login -u {username} -p {password} {registry-url}

docker push {registry-domain}/{image-name}:{version}
```

### Pull Docker images from your server

Now the Docker image has been uploaded into your docker private registry. To pull or run it in your server. Run cmd below:
```
docker login -u {username} -p {password} {registry-url}
docker pull {registry-domain}/{image-name}:{version}
```

```
docker login -u {username} -p {password} {registry-url}
docker run {some-options} {registry-domain}/{image-name}:{version}
```

Example: Using created username, password in a previous step to login to private registry, then pull the image.
```
docker login -u dev -p 123445 registry.my-site.com

docker pull registry.my-site.com/my-app:1.0.0
```

Example: Run the pulled image with name **my-app** and expose the port **8080**.
```
docker run -d --name my-app -p 8080:8080 registry.my-site.com/my-app:1.0.0
```

Now you can access this service in browser by `http://{your_vps_ip_address}:8080`.

But we don't want to access the app by using IP address, that is the reason why we buy a domain.

It's time to play with Nginx.

### Nginx site-enables configuration
Example: Create nginx configuration for http://my-site.com which listening on port 8080.
Consider to using reverse domain name for a config file name. You may find it's a useful trick when you using more than 1 sub domain.

```
cd /etc/nginx/site-enables
vi com.my-site
```
*Note that, there is no rule to name the setting file.*

Copy content to `com.my-site` file:
```
server {
  server_name my-site.com;

  location / {
    proxy_pass http://localhost:8080;
  }
}

server {
  listen 80;
}
```

Reload nginx
```
sudo nginx -s reload
```

Now you're able to access the app using `http://my-site.com` in your browser.

But where https? We'll do it in next step.

### Using Certbot Nginx plugin

To add SSL, TLS to your server, run cmdline below:
```
sudo certbot --nginx
```

Then, Certbot will scan `/etc/nginx/site-enables` and list scanned file into cmdline interfaces. Then you can choose which one (domain) you want to generate SSL, TLS.

Next, Certbot will do a http challenging and if you point the domain to correct IP address, this process will be OK.

Then, Certbot will ask you if you want to redirect non-secure request (http) to secure request with 2 options. You can decide which one you like most. In my cases, it always 2.

Next, you may need to restart nginx service to make it work (or maybe not).

Now you can access your app using `https://my-site.com`. Congratulations.

### Setup MongoDB for data storage

To set up Mongodb database with:
 - basic auth: username=admin, password=123456
 - db store in docker volume mongo-data.
 - maximum cache size in memory: 1GB
 - expose to port 27017

Notice: Double check _data folder in /mongo-data/ to ensure it existed.

```
docker volume create mongo-data

docker run -d --name some-mongo \
   -e MONGO_INITDB_ROOT_USERNAME=admin \
   -e MONGO_INITDB_ROOT_PASSWORD=123456 \
   -v /var/lib/docker/volumes/mongo-data/_data:/data/db \
   -p 27017:27017 \
   --wiredTigerCacheSizeGB 1 \
   mongo
```
