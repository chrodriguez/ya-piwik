#
# Cookbook Name:: ya-piwik
# Recipe:: default
#
# Copyright 2014, sharkpp
#
# The MIT License
#

include_recipe 'nginx'
include_recipe 'php'
include_recipe 'php::module_gd'
include_recipe 'php::module_xml'
include_recipe 'php::module_mbstring'
include_recipe 'php::module_mysql'

php_fpm_enabled = false
if node['ya-piwik'].attribute?('fpm') &&
   node['ya-piwik']['fpm'].attribute?('enable') &&
   node['ya-piwik']['fpm']['enable'] then
  include_recipe 'php::fpm'
  php_fpm_enabled = true
end

#####################################################
# var define

pkg_url  = node['ya-piwik']['package']
pkg_path = "#{Chef::Config[:file_cache_path]}/piwik-latest.tar.gz"
#ver_path = "#{Chef::Config[:file_cache_path]}/piwik-latest.txt"
home = node['ya-piwik']['home']
url = "http://localhost:80/piwik/"
nginx_sites_available = "#{node['nginx']['dir']}/sites-available/local-piwik"
nginx_sites_enabled   = "#{node['nginx']['dir']}/sites-enabled/local-piwik"
user  = !php_fpm_enabled ? "root" : node['ya-piwik']['fpm']['user']
group = !php_fpm_enabled ? "root" : node['ya-piwik']['fpm']['group']

#####################################################

# create home directory
directory home do
  owner user
  group group
  mode 00755
  recursive true
  action :create
  not_if { File.exist? home }
end

# download piwik
remote_file pkg_path do
  source pkg_url
  use_etag false
  use_last_modified false
  use_conditional_get false
  headers {}
  action :nothing
end
http_request "HEAD #{pkg_url}" do
  message ""
  url pkg_url
  action :head
  if File.exists?("#{pkg_path}")
    headers "If-Modified-Since" => File.mtime("#{pkg_path}").httpdate
  end
  notifies :create, "remote_file[#{pkg_path}]", :immediately
end

# extract piwik
bash 'extract_piwik' do
  cwd #{home}
  code <<-EOH
    tar xvf #{pkg_path} -C #{home} piwik
    mv #{home}/piwik/* #{home}
    rm -rf #{home}/piwik
    mkdir -pm 0755 #{home}/tmp/{assets,cache,logs,tcpdf,templates_c,sessions}
    chown -R #{user}:#{group} #{home}/*
  EOH
  not_if { ::File.exists?("#{home}/index.php") }
end

# setup php-fpm configuration
if php_fpm_enabled then
  php_fpm "ya-piwik" do
    action :add
    user user
    group group
    socket true
    socket_path node['ya-piwik']['fpm']['socket']
    socket_perms "0666"
    terminate_timeout (node['php']['ini_settings']['max_execution_time'].to_i + 20)
#   slow_filename "#{node['php']['fpm_log_dir']}/pkg.hsp-users.jp.slow.log"
    value_overrides({
#      :chdir => home
#      :error_log => "#{node['php']['fpm_log_dir']}/pkg.hsp-users.jp.error.log"
    })
  end
end

ruby_block "setup_piwik" do
  block do

    ctx = PhpHeadlessBrowser::Context.new(node.run_context)
    ctx.cwd = home

    # initialize piwik with create first user and site
    [
      { :path => 'index.php', :query => [ ], :data => [ ] },
      { :path => 'index.php', :query => [ "action=systemCheck" ], :data => [ ] },
      { :path => 'index.php', :query => [ "action=databaseSetup" ], :data => [ ] },
      { :path => 'index.php', :query => [ "action=databaseSetup" ],
                              :data =>  [ "host=#{node['ya-piwik']['database']['host']}",
                                          "username=#{node['ya-piwik']['database']['user']}",
                                          "password=#{node['ya-piwik']['database']['pass']}",
                                          "dbname=#{node['ya-piwik']['database']['name']}",
                                          "tables_prefix=#{node['ya-piwik']['database']['prefix']}",
                                          "adapter=#{node['ya-piwik']['database']['adapter']}" ] },
      { :path => 'index.php', :query => [ "action=setupSuperUser", "module=Installation" ], :data => [ ] },
      { :path => 'index.php', :query => [ "action=setupSuperUser", "module=Installation" ],
                              :data =>  [ "login=#{node['ya-piwik']['root']['user']}",
                                          "password=#{node['ya-piwik']['root']['pass']}",
                                          "password_bis=#{node['ya-piwik']['root']['pass']}",
                                          "email=#{node['ya-piwik']['root']['email']}" ] },
    # { :path => 'index.php', :query => [ "action=firstWebsiteSetup", "module=Installation" ], :data => [ ] },
      { :path => 'index.php', :query => [ "action=firstWebsiteSetup", "module=Installation" ],
                              :data =>  [ "siteName=MY%20FIRST%20SITE",
                                          "url=http://www.example.com/",
                                          "timezone=Asia/Tokyo#{node['ya-piwik']['root']['user']}",
                                          "ecommerce=0" ] },
    # { :path => 'index.php', :query => [ "action=trackingCode", "module=Installation" ], :data => [ ] },
      { :path => 'index.php', :query => [ "action=finished", "module=Installation" ], :data => [ ] }
    ].each do |w|

      PhpHeadlessBrowser.run(ctx, w[:path], w[:query], w[:data])

      # show error message
      error_msg = ctx.response[:body].match(%r{<div class="error">(.+?)</div>}m)
      error_msg = error_msg ? error_msg[1].gsub(/<.+?>/, '').gsub(/\s+/m, ' ') : '';
      if ! error_msg.empty? then
        Chef::Log.error(error_msg);
      end

      # test, was piwik installed? 
      if w[:query].empty? then
        if ctx.response[:body].include?("login_form") then
          Chef::Log.info("piwik was installed")
          break
        else
          # Delete the configuration file, it is because Setup will fail
          if File.exist?("#{home}/config/config.ini.php") then
            File.delete("#{home}/config/config.ini.php")
          end
        end
      end
    end

  end
  action :run
end
