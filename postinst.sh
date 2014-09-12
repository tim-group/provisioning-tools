#!/bin/sh

stupid_function() {
  sleep 2
  /etc/init.d/mcollective restart
}

stupid_function &
