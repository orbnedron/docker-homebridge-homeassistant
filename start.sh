#!/bin/sh

CONF=/config
PLUGINS=/plugins
CONF_SRC=/usr/src/app/conf
INSTALL_FILE=/config/install_plugins.sh
PACKAGE_FILE=/config/package.json

# if configuration file doesn't exist, copy the default
if [ ! -f $CONF/config.json ]; then
  cp $CONF_SRC/config.json.example $CONF/config.json
fi

# (Re-) Install specific Homebridge version to avoid incompatible updates
# with either Homebridge or iOS.
# -------------------------------------------------------------------------
# See https://github.com/marcoraddatz/homebridge-docker#homebridge_version
if [ "$HOMEBRIDGE_VERSION" ]
then
    echo "Force the installation of Homebridge version '$HOMEBRIDGE_VERSION'."

    npm install -g "homebridge@${HOMEBRIDGE_VERSION}" --unsafe-perm
fi

# (Re-) Install specific Homebridge-homeassistant plugin version to avoid incompatible updates
# with either Homebridge, iOS or Home-Assistant.
# -------------------------------------------------------------------------
if [ "$HA_HOMEBRIDGE_VERSION" ]
then
    echo "Force the installation of Homebridge-homeassistant plugin version '$HA_HOMEBRIDGE_VERSION'."

    npm install -g "homebridge-homeassistant@${HA_HOMEBRIDGE_VERSION}" --unsafe-perm
fi


# Install plugins via package.json
if [ -f "$PACKAGE_FILE" ]
then
    echo "Installing plugins from $PACKAGE_FILE."

    npm install
else
    echo "$PACKAGE_FILE not found."
fi

# Install plugins via install_plugins.sh
if [ -f "$INSTALL_FILE" ]
then
    echo "Installing plugins from $INSTALL_FILE."

    /bin/bash $INSTALL_FILE
else
    echo "$INSTALL_FILE not found."
fi



# Create directories
if [ ! -d /config/plugins ];
then
    mkdir -p /config/plugins
fi

if [ ! -d /config/persist ];
then
    mkdir -p /config/persist
fi

if [ ! -d /config/accessories ];
then
    mkdir -p /config/accessories
fi

# if ENV HA_URL is set, change the value in config.json
if [ -n "$HA_URL" ]; then
  sed -i "s/^            \"host\":.*/            \"host\": \"$(echo $HA_URL | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')\"/" $CONF/config.json
fi

# if ENV HA_KEY is set, change the value in config.json
if [ -n "$HA_KEY" ]; then
  sed -i "s/^            \"password\".*/            \"password\": \"$(echo $HA_KEY | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')\",/" $CONF/config.json
fi

# Lets run it!

rm -f /var/run/dbus/pid /var/run/avahi-daemon/pid

dbus-daemon --system
avahi-daemon -D

# Start Homebridge
if [ "$HOMEBRIDGE_ENV" ]
then
    case "$HOMEBRIDGE_ENV" in
        "debug-insecure" )
            DEBUG=* homebridge -I -D -U $CONF -P $PLUGINS ;;
        "development-insecure" )
            homebridge -I -U $CONF -P $PLUGINS ;;
        "production-insecure" )
            homebridge -I ;;
        "debug" )
            DEBUG=* homebridge -D -U $CONF -P $PLUGINS ;;
        "development" )
            homebridge -U $CONF -P $PLUGINS ;;
        "production" )
            homebridge -U $CONF ;;
    esac
else
    homebridge -U $CONF
fi