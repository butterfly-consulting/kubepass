#!/bin/bash
HOSTIP=$1
snap install --edge caddy

cat <<EOF >podsvc.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80  
---
kind: Service
apiVersion: v1
metadata:
  name: nginx-api
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    nodePort: 30080
  type: NodePort
---
kind: Service
apiVersion: v1
metadata:
  name: nginx-admin
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    nodePort: 30081
  type: NodePort
EOF

kubectl apply -f podsvc.yaml

# http://jordiburgos.com/post/2020/reverse-proxy-with-caddy-2.html
caddy stop

echo '{ email "michele@nimbella.com" }'>Caddyfile

echo "api-$HOSTIP.nip.io {" >>Caddyfile
multipass list | awk '/kube?/ { print "http://" $3 ":30080" }' \
| xargs echo "reverse_proxy " >>Caddyfile
echo "}" >>Caddyfile

echo "admin-$HOSTIP.nip.io {" >>Caddyfile
multipass list | awk '/kube?/ { print "http://" $3 ":30081" }' \
| xargs echo "reverse_proxy " >>Caddyfile
echo "}" >>Caddyfile

caddy fmt --overwrite

caddy start 2> caddy.log &
