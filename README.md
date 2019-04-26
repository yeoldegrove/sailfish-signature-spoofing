SailfishOS Android Signature Spoofing for XA2 devices
===
(or other devices using LXC containers for the android runtime)


Compatibility
===
This only works with Sailfish devices that uses the Android 8.* runtime, e.g. the "Xperia XA2".

If you are using an older Sailfish device, like the "Xperia X" which uses the Android 4.4 runtime, please checkout this: [sailfish-signature-spoofing](https://github.com/vermut/sailfish-signature-spoofing)

How this works
===

This is a compiled set of instructions and tools wrapped in Docker image to fetch, deodex, patch and upload back 
AlienDalvik files on Sailfish phones.

Most of the existing tools assume `adb` as transport. In Sailfish it's a bit tricky so I replaced it with Rsync. 
Please note that Rsync is run in completely insecure manner, so don't leave it running in public unprotected networks.

Overview of the steps performed by the scripts:
 * fetch via rsync `/opt/alien/system/{framework,app,priv-app}`
 * deodex using [vdexExtractor](https://github.com/anestisb/vdexExtractor)
 * apply `hook` and `core` patches from [haystack](https://github.com/Lanchon/haystack)
 * push back changed files, saving backups in `/home/nemo/system.img.pre.haystack`


Instructions
===

**Starting Rsync daemon on Sailfish**

* Make sure Android subsystem is stopped
* Make sure you PC is in connected to the same WiFi network as your phone
* Figure out your phone's IP address. It's shown in "Developer mode". We will use it later
* Enable [developer mode](https://jolla.zendesk.com/hc/en-us/articles/202011863-How-to-enable-Developer-Mode)
* Open terminal app or connect via SSH
* Become root by executing `devel-su`
* Create minimalistic Rsync config

```bash
cat > /root/rsyncd-alien.conf << 'EOF'
[alien]
 path=/opt/alien
 readonly=false
 uid=root
 gid=root 
EOF
```

* run daemon in foreground with logging

```bash
rsync --daemon --no-detach --verbose --config=/root/rsyncd-alien.conf --log-file=/dev/stdout
```

* make sure your firewall accepts connections on port 873
```bash
iptables -A connman-INPUT -i wlan0 -p tcp -m tcp --dport 873 -j ACCEPT
```

**Execute docker image**

Clone this repo from GitHub.

Make sure docker is available on you machine and running
* https://www.docker.com/docker-windows
* https://www.docker.com/docker-mac

Make sure you checked out all the code from the gut submodules, e.g.:

```bash
git submodule update --init --recursive
```

Make sure to pass `--env SAILFISH=` with the IP of the phone

```bash
docker run --rm -ti --env SAILFISH=<PHONE_IP_ADDRESS> yeoldegrove/sailfish-signature-spoofing-lxc
```

**Final steps**
* kill running rsync by pressing Ctrl-C
* start Android subsystem (or just run some app). *This will take time, depending on number of apps you have*
* From that point you can install [microG](https://microg.org/download.html) (nightly) [F-Droid](https://f-droid.org). 
Don't forget to enable "Unstable updates" from "Expert mode"


Reverting the changes (if needed)
===
```bash
cd /opt/alien/system
cp -r --reply=yes -v framework.pre_haystack/* framework/
cp -r --reply=yes -v app.pre_haystack/* app/
cp -r --reply=yes -v priv-app.pre_haystack/* priv-app/

cd /opt/alien/system_jolla
cp -r --reply=yes -v framework.pre_haystack/* framework/
cp -r --reply=yes -v app.pre_haystack/* app/
cp -r --reply=yes -v priv-app.pre_haystack/* priv-app/
```

**building the docker image yourself**

Make sure you checked out all the code from the gut submodules, e.g.:

```bash
git submodule update --init --recursive
```

```bash
docker build -t sailfish-signature-spoofing-lxc
```

Kudos
===
The code is based on a fork from the excelent work of [rfvermut](https://github.com/rfvermut) here:
 * [sailfish-signature-spoofing](https://github.com/vermut/sailfish-signature-spoofing)
