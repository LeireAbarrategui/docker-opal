#!/bin/bash

# Legacy parameters
if [ -n "$AGATE_PORT_8444_TCP_ADDR" ]
then
        AGATE_HOST=$AGATE_PORT_8444_TCP_ADDR
fi
if [ -n "$AGATE_PORT_8444_TCP_PORT" ]
then
        AGATE_PORT=$AGATE_PORT_8444_TCP_PORT
fi
if [ -n "$RSERVER_PORT_6312_TCP_ADDR" ]
then
        RSERVER_HOST=$RSERVER_PORT_6312_TCP_ADDR
fi

# Make sure conf folder is available
if [ ! -d $OPAL_HOME/conf ]
then
	echo "Preparing default conf in $OPAL_HOME ..."
	mkdir -p $OPAL_HOME/conf
	cp -r /usr/share/opal/conf/* $OPAL_HOME/conf
fi

# Install default plugins
if [ ! -d $OPAL_HOME/plugins ]
then
        echo "Preparing default plugins in $OPAL_HOME ..."
        mkdir -p $OPAL_HOME/plugins
        cp -r /usr/share/opal/plugins/* $OPAL_HOME/plugins
fi

#
# Agate
#

# check if 1st run. Then configure properties.
if [ -n "$AGATE_HOST" -a -e /opt/opal/bin/first_run.sh ]
then
	echo "Setting Agate connection..."
	if [ -z "$AGATE_PORT" ]
	then
		AGATE_PORT=8444
	fi
	sed s/localhost:8444/$AGATE_HOST:$AGATE_PORT/g $OPAL_HOME/conf/opal-config.properties | \
		sed s/#org.obiba.realm.url/org.obiba.realm.url/g > /tmp/opal-config.properties
	mv -f /tmp/opal-config.properties $OPAL_HOME/conf/opal-config.properties
fi

#
# R server
#

if [ -n "$RSERVER_HOST" -a -e /opt/opal/bin/first_run.sh ]
then
	echo "Setting R server connection..."
	sed s/#org.obiba.opal.Rserve.host=/org.obiba.opal.Rserve.host=$RSERVER_HOST/g $OPAL_HOME/conf/opal-config.properties > /tmp/opal-config.properties
	mv -f /tmp/opal-config.properties $OPAL_HOME/conf/opal-config.properties
  if [ -n "$R_REPOS" ]
  then
    echo "org.obiba.opal.r.repos=$R_REPOS" >> $OPAL_HOME/conf/opal-config.properties
  fi
fi

#
# Administrator password
#

if [ -e /opt/opal/bin/set_password.sh ]
then
	echo "Setting password..."
	/opt/opal/bin/set_password.sh
	mv /opt/opal/bin/set_password.sh /opt/opal/bin/set_password.sh.done
fi

# Start opal
if [ -e /opt/opal/bin/first_run.sh ]
then
	echo "Starting Opal before first run script..."
	# check if 1st run. Then configure database and datashield.
	/usr/share/opal/bin/opal &
	# Wait for the opal server to be up and running
	echo "Waiting for Opal to be ready..."
	until opal rest -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD -m GET /system/databases &> /dev/null
	do
		sleep 5
	done
	echo "First run setup..."
	/opt/opal/bin/first_run.sh
	mv /opt/opal/bin/first_run.sh /opt/opal/bin/first_run.sh.done
	ls /srv/plugins
	tail -f $OPAL_HOME/logs/opal.log
else
	echo "Starting Opal..."
	/usr/share/opal/bin/opal
fi
