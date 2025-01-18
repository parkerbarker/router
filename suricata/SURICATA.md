# Parker Barker Proxy Installation Guide

## Overview

The **Parker Barker Proxy** project sets up a Raspberry Pi server to manage internet traffic for your home network. The server will monitor and route traffic using **Suricata**.

### Prerequisites

- Raspberry Pi 5 (8GB RAM) with **Raspberry Pi OS Lite (64-bit)** freshly installed.
- The Raspberry Pi is connected to the **OPNsense router** with the IP address `192.168.1.103`.

### Post Installation Quick Reference

```bash
sudo tail -f /var/log/suricata/eve.json
sudo tail -f /var/log/suricata/fast.log
sudo tail -f /var/log/suricata/stats.log
sudo tail -f /var/log/suricata/suricata.log

# test rules
sudo suricata -T

# systemctl
sudo systemctl start|stop|status suricata
sudo vim /lib/systemd/system/suricata.service

sudo suricatasc -c ruleset-reload-nonblocking
```

---

## Step 1: Prepare System

**Purpose**: Ensure the system is up to date.

1. Update the Raspberry Pi system:

    ```bash
    sudo apt update && sudo apt upgrade -y
    ```

## Step 2: Install Suricata

**Purpose**: `Suricata` will monitor and analyze network traffic.

### Instructions

1. Install `Suricata` dependencies:

    ```bash
    sudo apt install -y software-properties-common
    ```

2. Install `Suricata`:

    ```bash
    sudo apt install suricata -y
    ```

3. Download the default rule set:

    ```bash
        sudo apt install suricata-update -y
        sudo suricata-update update-sources
        sudo suricata-update


        # Confirm its working
        sudo suricata-update list-sources

        # The rules file is located in /var/lib/suricata/rules/suricata.rules
        # suricata by default looks for it in /etc/suricata/rules/suricata.rules
        # Lets use a symlink instead of customizing the config

        sudo ln -s /var/lib/suricata/rules/suricata.rules /etc/suricata/rules/suricata.rules
    ```


5. Configure AF-Packet to listen on your ethernet port

    ```bash
    # get name of port
    # ex: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP>
    ip addr

    # edit af-packet
    sudo vim +588 /etc/suricata/suricata.yaml
    ```

    ```yaml
      af-packet:
        - interface: enp4s0
          use-mmap: yes
    ```

6. Restart the Suricata service to apply the changes:

    ```bash
    sudo systemctl restart suricata
    ```

### Test Suricata

- Check the installed version:

    ```bash
    suricata -V
    ```

- Verify the rule files:

    ```bash
    ls /etc/suricata/rules/
    ```

- Check logs to confirm suricata is running

    ```bash
    sudo tail /var/log/suricata/suricata.log
    ```

- Generate HTTP traffic using `curl`:

    ```bash
    curl http://example.com
    ```

  Check the Suricata `eve.json` log to see if the traffic is being analyzed:

    ```bash
    sudo tail -f /var/log/suricata/eve.json
    ```

  You should see entries in the `eve.json` file indicating that Suricata has processed the HTTP traffic.

- Generate HTTPS traffic using `curl`:

    ```bash
    curl https://example.com
    ```

  Again, check the Suricata `eve.json` log to see if the traffic is being analyzed:

    ```bash
    sudo tail -f /var/log/suricata/eve.json
    ```

  You should see entries in the `eve.json` file indicating that Suricata has processed the HTTPS traffic.

## Conclusion

You have successfully set up the **Parker Barker Proxy** to manage your home internet traffic using `Suricata`. For further configuration and customization, refer to the official documentation of each tool.

More details: [Suricata Quickstart](https://docs.suricata.io/en/latest/quickstart.html)
