#
# Cookbook Name:: ya-piwik
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

default['ya-piwik']['home'] = '/var/www/html/piwik/'
default['ya-piwik']['socket'] = '/var/run/php-fpm/piwik.php-fpm.sock'

default['ya-piwik']['database']['host'] = '127.0.0.1'
default['ya-piwik']['database']['user'] = 'root'
default['ya-piwik']['database']['pass'] = 'qazwsx'
default['ya-piwik']['database']['name'] = 'piwik'
default['ya-piwik']['database']['prefix'] = ''
default['ya-piwik']['database']['adapter'] = 'MYSQLI'

default['ya-piwik']['root']['user'] = 'root'
default['ya-piwik']['root']['pass'] = '!qaz2wsx'
default['ya-piwik']['root']['email'] = 'webmaster@sharkpp.net'
