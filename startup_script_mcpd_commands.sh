#!/bin/bash
# Filename: /config/startup_script_mcpd_commands.sh
export myFileName=/config/startup_script_mcpd_commands.sh

export mysshkey=<key here>

export REMOTEUSER=root

# Limit to 5 times in while-loop, ie. 4 x 30 secs sleep = 2 mins.
MAX_LOOP=5

while true
do
MCPD_RUNNING=`ps aux | grep "/usr/bin/mcpd" | grep -v grep | wc -l`

if [ "$MCPD_RUNNING" -eq 1 ]; then
# Here you could perform customized command(s) after MCPD is found running when the BIG-IP system starts up.
# Customized startup command(s) can be added below this line.

  if [ ! -f /root/.startup_script_mcpd_commands.done ]; then

    sleep 60

    logger -p local0.notice -t $myFileName customization script setup disabled, timezone, auth timeout, records 30, dns resolver, ocsp

    tmsh modify auth password-policy policy-enforcement disabled

    tmsh modify sys global-settings gui-setup disabled

    tmsh modify sys ntp timezone America/New_York

    tmsh modify sys httpd auth-pam-idle-timeout 7200

    tmsh modify sys db ui.system.preferences.recordsperscreen value 30

    # tmsh create net dns-resolver ocsp-resolver cache-size 5767168

    # tmsh create sys crypto cert-validator ocsp ocsp_sslo route-domain 0 dns-resolver ocsp-resolver signer-cert default.crt signer-key default.key sign-hash sha1

    tmsh modify sys db dhclient.mgmt value enable

    tmsh create net vlan VLAN_10 { interfaces add { 1.1 { } } sflow { poll-interval-global no sampling-rate-global no } }

    tmsh create net vlan VLAN_20 { interfaces add { 1.2 { } } sflow { poll-interval-global no sampling-rate-global no } }

    printf 'default\ndefault\n' | tmsh modify sys crypto master-key prompt-for-password

    myHOSTNAME=$(dmidecode -t system | grep -i 'Product Name:' | awk {'print $3'})

    if [ ! -z $myHOSTNAME ]; then
      tmsh modify sys global-settings hostname $myHOSTNAME
    fi

    if [ ! -f /root/.sshKeysAdded ]; then

      logger -p local0.notice /config/startup: Adding ssh keys to /root/.ssh/authorized_keys
      echo $mysshkey >> /root/.ssh/authorized_keys
      touch /root/.sshKeysAdded
    fi

    sleep 10

    tmsh save sys config

    # tmsh modify sys provision apm ilx ltm level nominal

    touch /root/.startup_script_mcpd_commands.done

  fi

  # apply license from dmidecode (serial)

  mySERIAL=$(dmidecode -t system | grep -i 'Serial Number:' | awk {'print $3'})

  if [ ! -f /root/.startup_script_license_commands.done ]; then

    if [ ! -z $mySERIAL ]; then
      logger -p local0.notice -t $myFileName Serial $mySERIAL found in dmidecode. Attempting to register.

      ((count = 10))                            # Maximum number to try.
      while [[ $count -ne 0 ]] ; do
        ping -c 1 activate.f5.com             # Try once.
        rc=$?
        if [[ $rc -eq 0 ]]; then
          ((count = 1))                     # If okay, flag to exit loop.
        fi
        ((count = count - 1))                 # So we don't go forever.
        sleep 30
      done

      if [[ $rc -eq 0 ]]; then                  # Make final determination.
        logger -p local0.notice -t $myFileName attempting to activate key.
        sleep 10
        /usr/local/bin/SOAPLicenseClient --basekey $mySERIAL | logger -p local0.notice -t $myFileName
        touch /root/.startup_script_license_commands.done
      else
        logger -p local0.notice -t $myFileName activate.f5.com unreachable or timeout.
      fi
    fi
  fi

  # Customized startup command(s) should end above this line.
  logger -p local0.notice -t $myFileName Customization complete, exiting script.

  exit
fi

# If MCPD is not ready yet, script sleep 30 seconds and check again.
sleep 30

# Safety check not to run this script in background beyond 2 mins (ie. 4 times in while-loop).
if [ "$MAX_LOOP" -eq 1 ]; then
  logger -p local0.notice -t $myFileName MCPD not started within 2 minutes. Exiting script.
  exit
fi
((MAX_LOOP--))
done

# End of file /config/startup_script_mcpd_commands.sh
