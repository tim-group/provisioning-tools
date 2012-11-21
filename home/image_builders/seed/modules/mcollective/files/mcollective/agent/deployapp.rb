libdir = "/opt/deploytool/lib"
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)
require 'agent/Deployapp'
