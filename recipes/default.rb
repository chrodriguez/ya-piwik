#
# Cookbook Name:: ya-piwik
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'nginx'
include_recipe 'php'
include_recipe 'php::module_gd'
include_recipe 'php::module_xml'
include_recipe 'php::module_mbstring'
include_recipe 'php::module_mysql'

#####################################################
# var define

pkg_url  = "http://builds.piwik.org/piwik-latest.tar.gz"
pkg_path = "#{Chef::Config[:file_cache_path]}/piwik-latest.tar.gz"
#ver_path = "#{Chef::Config[:file_cache_path]}/piwik-latest.txt"
home = node['ya-piwik']['home']
url = "http://localhost:80/piwik/"
nginx_sites_available = "#{node['nginx']['dir']}/sites-available/local-piwik"
nginx_sites_enabled   = "#{node['nginx']['dir']}/sites-enabled/local-piwik"
user  = 'nginx'
group = 'nginx'

#####################################################

# create home directory
directory home do
	owner user
	group group
	mode 00755
	recursive true
	action :create
end

# download piwik
remote_file pkg_path do
  source pkg_url
  action :nothing
end
http_request "HEAD http://builds.piwik.org/piwik-latest.tar.gz" do
  message ""
  url pkg_url
  action :head
  if File.exists?("#{pkg_path}")
    headers "If-Modified-Since" => File.mtime("#{pkg_path}").httpdate
  end
  notifies :create, "remote_file[#{pkg_path}]", :immediately
end

# extract piwik
bash 'extract piwik' do
  cwd #{home}
  code <<-EOH
    tar xvf #{pkg_path} -C #{home} piwik
    mv #{home}/piwik/* #{home}
    rmdir #{home}/piwik
    chown -R #{user}:#{group} #{home}/*
  EOH
  not_if { ::File.exists?("#{home}/index.php") }
end

# setup php-fpm configuration
php_fpm "ya-piwik" do
  action :add
  user user
  group group
  socket true
  socket_path node['ya-piwik']['socket']
  socket_perms "0666"
  terminate_timeout (node['php']['ini_settings']['max_execution_time'].to_i + 20)
# slow_filename "#{node['php']['fpm_log_dir']}/pkg.hsp-users.jp.slow.log"
  value_overrides({
#    :chdir => home
#    :error_log => "#{node['php']['fpm_log_dir']}/pkg.hsp-users.jp.error.log"
  })
  env_overrides({
    :FUEL_ENV => "production"
  })
end

#{node["ya-piwik"]["root"]["user"]}
#{node["ya-piwik"]["root"]["pass"]}
#{node["ya-piwik"]["root"]["email"]}


# initialize piwik with create first user and site
# bash 'initialize piwik' do
#   cwd #{home}
#   code <<-EOH
#     
#   EOH
#   code_ <<-EOH
#     curl               -c tmp/cookie -L -X GET "#{url}" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -L -X GET "#{url}?action=systemCheck" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -L -X GET "#{url}?action=databaseSetup" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -L -d 'host=#{node["ya-piwik"]["database"]["host"]}' \
#                                         -d 'username=#{node["ya-piwik"]["database"]["user"]}' \
#                                         -d 'password=#{node["ya-piwik"]["database"]["pass"]}' \
#                                         -d 'dbname=#{node["ya-piwik"]["database"]["name"]}' \
#                                         -d 'tables_prefix=#{node["ya-piwik"]["database"]["prefix"]}' \
#                                         -d 'adapter=#{node["ya-piwik"]["database"]["adapter"]}' \
#                                         -X POST "#{url}?action=databaseSetup" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -L -X GET "#{url}?action=generalSetup&amp;module=Installation" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -d 'login=#{node["ya-piwik"]["root"]["user"]}' \
#                                      -d 'password=#{node["ya-piwik"]["root"]["pass"]}' \
#                                      -d 'password_bis=#{node["ya-piwik"]["root"]["pass"]}' \
#                                      -d 'email=#{node["ya-piwik"]["root"]["email"]}' \
#                                      -X POST "#{url}?action=generalSetup&amp;module=Installation" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -L -X GET "#{url}?action=firstWebsiteSetup&amp;module=Installation" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -d 'siteName=pkg.hsp-users.jp' \
#                                      -d 'url=http://pkg.hsp-users.jp/' \
#                                      -d 'timezone=Asia/Tokyo' \
#                                      -d 'ecommerce=0' \
#                                      -X POST "#{url}?action=firstWebsiteSetup&amp;module=Installation" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -L -X GET "#{url}?action=trackingCode&amp;module=Installation" >/dev/null
#     curl -b tmp/cookie -c tmp/cookie -L -X GET "#{url}?action=finished&amp;module=Installation" >/dev/null
#     rm -f tmp/cookie
#   EOH
#   not_if { ::File.exists?("#{home}/config/config.inc.php") }
# end

#include_recip
define :piwik_xxxx,
       :action => :create,
       :timezone => "Asia/Tokyo",
       :ecommerce => "0" do
#  params[:name]
#  params[:action]
#  params[:siteName]
#  params[:url]
#  params[:timezone]
#  params[:ecommerce]
end

