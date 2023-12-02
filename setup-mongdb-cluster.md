1. Add `mongodb` user:
```
adduser mongodb
```

2. Make working directory
```
mkdir database && cd database
```

3.1. in primary machine, generate keyfile
```
openssl rand -base64 756 > keyfile.txt
```

3.2. in secondary machine, copy its generate file from primary
```
scp {username}@{primary-ip}:~/database/keyfile.txt .
```

4. grant permission
```
chmod 400 keyfile.txt
chown mongodb:mongodb keyfile.txt
```

5. making database folder
```
mkdir data && cd data && mkdir db && cd ..
chown -R mongodb data/db
```

6. get mongodb user id (not sure needed or not)
```
id mongodb // usually 999 or 1000
```

6.1. Run docker in each cluster machines (at least 3)
```
docker run -d --name mongodb --restart=unless-stopped \
  --user {mongodb_id}:{mongodb_id} \
  -e MONGO_INITDB_ROOT_USERNAME={db_username} \
  -e MONGO_INITDB_ROOT_PASSWORD={db_password} \
  -v "$(pwd)"/data/db:/data/db \
  -v "$(pwd)"/keyfile.txt:/keyfile \
  -p 27017:27017 \
mongo@latest --replSet "replicasetName" --keyFile /keyfile
```

6.2. Enable replica set

At primary machine run
```
docker exec -it mongodb mongosh --eval "rs.initiate({
 _id: \"replicasetName\",
 members: [
   {_id: 0, host: \"ip-machine-1:port\"},
   {_id: 1, host: \"ip-machine-1:port\"},
   {_id: 2, host: \"ip-machine-1:port\"}
 ]
})"
```

For example:
```
// machine 1: 192.168.0.5
// machine 2: 192.168.0.6
// machine 3: 192.168.0.7

docker exec -it mongodb mongosh --eval "rs.initiate({
 _id: \"replicasetName\",
 members: [
   {_id: 0, host: \"192.168.0.5:27017\"},
   {_id: 1, host: \"192.168.0.5:27017\"},
   {_id: 2, host: \"192.168.0.5:27017\"}
 ]
})"
```

----

- You can then add more machine to replica set by `rs.add('ip:port')`, or remove it by `rs.remove('ip:port')`
- Use `rs.status()` to get current status of replica set
- Use `rs.stepDown()` from primary db to make it become secondary, other secondary will be voted to become primary.
