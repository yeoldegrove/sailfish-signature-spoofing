SailfishOS Android Signature Spoofing
===

This is a compiled set of instructions and tools wrapped in Docker image to fetch, deodex, patch and upload back 
AlienDalvik files on Sailfish phones.

Most of the existing tools assume `adb` as transport. In Sailfish it's a bit tricky so I replaced it with Rsync. 
Please note that Rsync is run in completely insecure manner, so don't leave it running in public unprotected networks.

Overview of the steps performed by the scripts:
 * fetch via rsync `/opt/alien/system/{framework,app,priv-app}`
 * deodex using [simple-deodexer](https://github.com/aureljared/simple-deodexer) on non LXC system (android 4.4)
 * deodex using [vdexExtractor](https://github.com/anestisb/vdexExtractor) on LXC system (android 8.1)
 * apply `hook` and `core` patches from [haystack](https://github.com/Lanchon/haystack)
 * push back changed files, saving backups in `/opt/alien/system/{framework,app,priv-app}.pre_haystack` (nonLXC/android 4.4) or `/opt/alien/system.img.pre.haystack` (LXC/android 8.1)

Instructions
===

**Starting Rsync daemon on Sailfish**

* Make sure Android subsystem is stopped
* Connect your PC to the phone (either with USB or both connected to the same WiFi network)
* Enable [developer mode](https://jolla.zendesk.com/hc/en-us/articles/202011863-How-to-enable-Developer-Mode)
* Figure out your phone's IP address. It's shown in *Settings* -> *Developer tools*. We will use it later

  For USB that would usually be 192.168.2.15
* Open terminal app or connect via SSH
* Become root by executing `devel-su`
* Create minimalistic Rsync config

```bash
cat > /root/rsyncd-alien.conf << 'EOF'
[alien]
 path=/opt/alien
 readonly=false
 use chroot=true
 munge symlinks=false
 uid=root
 gid=root 
EOF
```

* run daemon in foreground with logging

```bash
rsync --daemon --no-detach --verbose --address=192.168.2.15 --config=/root/rsyncd-alien.conf --log-file=/dev/stdout
```

  If you're using an SSH tunnel, use `--address=127.0.0.1` to retrict the daemon to the tunnel only

  If you're not using USB, replace `192.168.2.15` with the address of your device on the corresponding network (see *Settings* -> *Developer tools*)

* make you daemon accessible

  * Solution 1: use an `ssh` firewall (see `--end SSH=1` parameter below)

  * Solution 2: make sure your firewall accepts connections on port 873 over Wifi
```bash
iptables -A connman-INPUT -i wlan0 -p tcp -m tcp --dport 873 -j ACCEPT
```

**Build and execute docker image**

Clone this repo from GitHub.

Make sure docker is available on you machine and running
* https://www.docker.com/docker-windows
* https://www.docker.com/docker-mac

Make sure you checked out all the code from the gut submodules, e.g.:

```bash
git submodule update --init --recursive
```

Make sure to pass `--env SAILFISH=` with the IP of the phone (on USB that would be `192.168.2.15`)

Make sure to pass `--env LXC=0` or `--env LXC=1` to choose between android 4.4 (non LXC) and android 8.1 (LXC)

If you want to use a SSH tunnel for added security pass `--env SSH=1`.

```bash
docker build -t haystack . && docker run --rm -ti --env SAILFISH=<PHONE_IP_ADDRESS> --env LXC=0/1 --env SSH=0/1 haystack
```

**Final steps**
* kill running rsync by pressing Ctrl-C
* start Android subsystem (or just run some app). *This will take time, depending on number of apps you have*
* From that point you can install [microG](https://microg.org/download.html) (nightly) [F-Droid](https://f-droid.org). 
Don't forget to enable "Unstable updates" from "Expert mode"


**Before Sailfish X upgrades with  android 8.1 LXC**

There is not enough free space in `/opt`partition to hold the current (patched) *system.img*, the upgrades and the backup all at the same time.

Either delete the backup from `/opt/alien/system.img.pre_haystack` or move this file to your SD card.

Then don't forget to re-run the patch to patch your new upgraded Android *system.img*.



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


