#
# Cookbook Name:: ya-piwik
# Attribute:: default
#
# Copyright 2014, sharkpp
#
# The MIT License
#

default['ya-piwik']['home'] = '/var/www/html/piwik/'

default['ya-piwik']['package'] = 'http://builds.piwik.org/piwik-latest.tar.gz'

default['ya-piwik']['fpm']['enable'] = true
default['ya-piwik']['fpm']['user'] = 'nginx'
default['ya-piwik']['fpm']['group'] = 'nginx'
default['ya-piwik']['fpm']['socket'] = '/var/run/php-fpm/piwik.php-fpm.sock'

default['ya-piwik']['database']['host'] = '127.0.0.1'
default['ya-piwik']['database']['user'] = 'root'
default['ya-piwik']['database']['pass'] = 'secret-password-here'
default['ya-piwik']['database']['name'] = 'piwik'
default['ya-piwik']['database']['prefix'] = ''
default['ya-piwik']['database']['adapter'] = 'MYSQLI'

default['ya-piwik']['root']['user'] = 'root'
default['ya-piwik']['root']['pass'] = 'secret-password-here'
default['ya-piwik']['root']['email'] = 'piwik@example.net'
