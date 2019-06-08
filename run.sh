#!/bin/bash

if [ -z "${SAILFISH}" ]; then
    SAILFISH=192.168.2.15
    echo -e "\e[33;1mWARNING:\e[0m no address specified, falling back to USB: ${SAILFISH}"
else
    echo Looking for Sailfish device at address: ${SAILFISH}
fi

if (( $SSH )); then
    echo -e "\e[34;1m=================================\e[37;1m"
    echo [**] 0. Establish SSH tunnel
    echo -e "\e[34;1m=================================\e[0m"
    if ! ssh -L 127.0.0.1:873:127.0.0.1:873 nemo@${SAILFISH} -Nf; then
        echo -e "\e[31;1mERROR:\e[0m couldn't start tunnel. falling back to direct connection"
    else
        echo "SSH Tunnel established"
        SSHTUNNELACTIVE=1
        SAILFISH=127.0.0.1
    fi
fi

set -e
SYSTEM_PATH=system

rsync_error () {
    echo -e "\e[31;1mERROR:\e[0m cannot download from rsync daemon"
    echo "- Did you remember to start the daemon with option '--address=${SAILFISH}'"
    case "${SAILFISH}" in
        127.0.0.1)
            echo "- Did the tunnel setup abov fail?"
            echo "- Alternatively use this docker on a direct connection with '--env SSH=0' instead"
        ;;
        192.168.2.15)
            ## USB isn't actually blocked by firewall on current versions of Sailfish OS
            #echo "- If connected over USB, did you remember to open the firewall port:"
            #echo "  iptables -A connman-INPUT -i rndis0 -p tcp -m tcp --dport 873 -j ACCEPT"
            echo "- Or alternatively use this docker on a SSH tunnel with '--env SSH=1' instead"
        ;;
        *)
            echo "- If connected over Wifi, did you remember to open the firewall port:"
            echo "  iptables -A connman-INPUT -i wlan0 -p tcp -m tcp --dport 873 -j ACCEPT"
            echo "- Or alternatively use this docker on a SSH tunnel with '--env SSH=1' instead"
        ;;
    esac
    exit 1
}


echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 1. Fetch files via RSYNC
echo -e "\e[34;1m=================================\e[0m"
rsync -vaP \
    rsync://${SAILFISH}/alien/system.img \
    /tmp/system.img || rsync_error

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 1.1 unpack the squashfs
echo -e "\e[34;1m=================================\e[0m"
cd /tmp && unsquashfs system.img

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 1.2 get files to patch
echo -e "\e[34;1m=================================\e[0m"
mkdir -p /sailfish
rsync -va /tmp/squashfs-root/${SYSTEM_PATH}/{framework,app,priv-app} \
  /sailfish

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 2. Deodex the vdex and dex files
echo -e "\e[34;1m=================================\e[0m"
#cd /vdexExtractor/bin && ./vdexExtractor -i /sailfish --ignore-crc-error
cd /vdexExtractor/bin && ./vdexExtractor -i /sailfish/framework/oat/arm/services.vdex --ignore-crc-error
echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 2. add classes.dex to services.jar
echo -e "\e[34;1m=================================\e[0m"
cp /sailfish/framework/oat/arm/services_classes.dex /tmp/classes.dex
zip -j /sailfish/framework/services.jar /tmp/classes.dex

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 3. Apply the patch
echo -e "\e[34;1m=================================\e[0m"
API_VERSION=27
rm -rf /sailfish/hook
/haystack/patch-fileset /haystack/patches/sigspoof-hook-7.0-9.0 ${API_VERSION} /sailfish/framework /sailfish/hook
rm -rf /sailfish/hook_core
/haystack/patch-fileset /haystack/patches/sigspoof-core ${API_VERSION} /sailfish/hook /sailfish/hook_core
rm -rf /sailfish/hook_unifiednlp
/haystack/patch-fileset /haystack/patches/unifiednlp-7.0 ${API_VERSION} /sailfish/hook_core /sailfish/hook_unifiednlp

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 4. Merge back the results
echo -e "\e[34;1m=================================\e[0m"
mv -v /sailfish/hook_unifiednlp/* /sailfish/framework/

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 5.1 Merge results back
echo -e "\e[34;1m=================================\e[0m"
rsync -va \
    /sailfish/framework/services.jar \
    /tmp/squashfs-root/${SYSTEM_PATH}/framework/
# rsync -va \
#     /sailfish/framework/ \
#     /tmp/squashfs-root/${SYSTEM_PATH}/framework/
# rsync -va \
#     /sailfish/app/ \
#     /tmp/squashfs-root/${SYSTEM_PATH}/app/
# rsync -va \
#     /sailfish/priv-app/ \
#     /tmp/squashfs-root/${SYSTEM_PATH}/priv-app/

if [[ "$NOMAPS" != "1" ]]; then
  echo -e "\e[34;1m=================================\e[37;1m"
  echo [**] 5.1.1 Install MicroG Maps API -- mapsv1
  echo -e "\e[34;1m=================================\e[0m"
  unzip -d /tmp/squashfs-root/ /mapsv1.flashable.zip  'system/framework/*'
fi

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 5.2 rebuild squashfs
echo -e "\e[34;1m=================================\e[0m"
cd /tmp && mksquashfs squashfs-root system.img.haystack -comp lz4 -Xhc -noappend -no-exports -no-duplicates -no-fragments

echo -e "\e[34;1m=================================\e[37;1m"
echo [**] 5. Upload results back
echo -e "\e[34;1m=================================\e[0m"
rsync -vaP --delete-after -b --suffix=".pre_haystack" \
    /tmp/system.img.haystack \
    rsync://${SAILFISH}/alien/system.img

if (( $SSHTUNNELACTIVE )); then
    : #killall -2 ssh
fi
