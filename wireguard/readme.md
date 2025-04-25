# [WireGuard Easy](https://github.com/wg-easy/wg-easy/tree/production)


[WireGuard](https://www.wireguard.com) is a fast, modern, and secure VPN tunnel protocol that is simple to set up and maintain.
[wg-easy](https://github.com/wg-easy/wg-easy/tree/production) is a web UI and Docker container that makes it incredibly easy to manage your WireGuard VPN server — just plug and play.

## 🔐 Generate a Hashed Password for WG-Easy Login

WG-Easy uses basic authentication for its web interface. To set your admin password securely, generate a hashed password with the following command:

```bash
sudo docker run ghcr.io/wg-easy/wg-easy wgpw MY_COOL_PASSWORD
```
> ⚠️ **Important!**: Escape each $ as $$ in the docker-compose.yml because YAML interprets $ as a variable, and Docker Compose will later evaluate it.

## ⚙️ Edit docker-compose.yml

Download the [docker-compose.yml](https://github.com/wg-easy/wg-easy/blob/production/docker-compose.yml) and edit it:

```yaml
volumes:
  etc_wireguard:

services:
  wg-easy:
    environment:
      # Change Language:
      # (Supports: en, ua, ru, tr, no, pl, fr, de, ca, es, ko, vi, nl, is, pt, chs, cht, it, th, hi)
      - LANG=en
      # ⚠️ Required:
      # Change this to your host's public address
      - WG_HOST=raspberrypi.local

      # Optional:
      # - PASSWORD_HASH=$$2y$$10$$hBCoykrB95WSzuV4fafBzOHWKu9sbyVa34GJr8VV5R/pIelfEMYyG (needs double $$, hash of 'foobar123'; see "How_to_generate_an_bcrypt_hash.md" for generate the hash)
      # - PORT=51821
      # - WG_PORT=51820
      # - WG_CONFIG_PORT=92820
      # - WG_DEFAULT_ADDRESS=10.8.0.x
      # - WG_DEFAULT_DNS=1.1.1.1
      # - WG_MTU=1420
      - WG_ALLOWED_IPS=192.168.0.0/24, 10.0.1.0/24
      # - WG_PERSISTENT_KEEPALIVE=25
      # - WG_PRE_UP=echo "Pre Up" > /etc/wireguard/pre-up.txt
      # - WG_POST_UP=echo "Post Up" > /etc/wireguard/post-up.txt
      # - WG_PRE_DOWN=echo "Pre Down" > /etc/wireguard/pre-down.txt
      # - WG_POST_DOWN=echo "Post Down" > /etc/wireguard/post-down.txt
      # - UI_TRAFFIC_STATS=true
      # - UI_CHART_TYPE=0 # (0 Charts disabled, 1 # Line chart, 2 # Area chart, 3 # Bar chart)

    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    volumes:
      - etc_wireguard:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
      # - NET_RAW # ⚠️ Uncomment if using Podman 
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
```

## 🚀 Start the WireGuard Easy Container

Run the following command to start the container in the background:

```bash
docker compose up --detach
```
The `-d` (or `--detach`) flag runs the container in detached mode.

## 📌 Notes
1. Use a domain from Cloudflare or another domain provider. If you're using Cloudflare, create a vpn CNAME (e.g., vpn.yourdomain.com) and **disable the proxy** (set it to "DNS only") so WireGuard can connect directly.
2. On your home router, forward UDP traffic from the chosen port (default: 51820) to the local IP address of the machine running the WireGuard container.
3. 🔒 For security reasons, **do not expose** the web UI (51821) to the internet. Do not create a port forwarding rule for it in your router — access the web portal only from within your local network.
