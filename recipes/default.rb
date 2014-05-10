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

#####################################################
# var define

pkg_url  = "http://builds.piwik.org/piwik-latest.tar.gz"
pkg_path = "#{Chef::Config[:file_cache_path]}/piwik-latest.tar.gz"
#ver_path = "#{Chef::Config[:file_cache_path]}/piwik-latest.txt"
home = node['ya-piwik']['home']
url = "http://localhost:80/piwik/"
nginx_sites_available = "#{node['nginx']['dir']}/sites-available/local-piwik"
nginx_sites_enabled   = "#{node['nginx']['dir']}/sites-enabled/local-piwik"
user  = node['ya-piwik']['fpm']['user']
group = node['ya-piwik']['fpm']['group']

#####################################################

ctx = PhpHeadlessBrowser::Context.new

PhpHeadlessBrowser.run(ctx, 'index2.php')

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
if node['ya-piwik'].attribute?('fpm') &&
   node['ya-piwik']['fpm'].attribute?('enable') &&
   node['ya-piwik']['fpm']['enable']
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

session_tmp = Tempfile.new('session')
session_cookie = ''

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
  { :path => 'index.php', :query => [ "action=generalSetup", "module=Installation" ], :data => [ ] },
  { :path => 'index.php', :query => [ "action=generalSetup", "module=Installation" ],
                          :data =>  [ "login=#{node['ya-piwik']['root']['user']}",
                                      "password=#{node['ya-piwik']['root']['pass']}",
                                      "password_bis=#{node['ya-piwik']['root']['pass']}",
                                      "email=#{node['ya-piwik']['root']['email']}" ] },
# { :path => 'index.php', :query => [ "action=firstWebsiteSetup", "module=Installation" ], :data => [ ] },
  { :path => 'index.php', :query => [ "action=firstWebsiteSetup", "module=Installation" ],
                          :data =>  [ "siteName=pkg.hsp-users.jp",
                                      "url=http://pkg.hsp-users.jp/",
                                      "timezone=Asia/Tokyo",
                                      "ecommerce=0" ] },
# { :path => 'index.php', :query => [ "action=trackingCode", "module=Installation" ], :data => [ ] },
  { :path => 'index.php', :query => [ "action=finished", "module=Installation" ], :data => [ ] }
].each do |w|

  query = w[:query].join("&")
  data  = w[:data].join("&")

  for i in (1..5).to_a # maximum 5 redirect support

    # execute php-cgi
    b = bash "call php-cgi" do
  
      cwd_   = home
      path   = '/piwik/'
      realpath= 'index.php'
      ip     = '127.0.0.1'
      host   = 'localhost'
      port   = '80'
      cookie = session_cookie
  
      cwd cwd_
      code <<-EOH
#       echo "**************** path=#{path}"
#       echo "**************** query=#{query}"
#       echo "**************** data=#{data}"
#       echo "**************** cookie=#{cookie}"
        echo '#{data}' | php-cgi > "#{session_tmp.path}"
#        cat "#{session_tmp.path}" | head -n 20
      EOH
      environment 'DOCUMENT_ROOT' => cwd_,
                  'HOME' => cwd_,
                  'SCRIPT_FILENAME' => realpath,
                  'DOCUMENT_URI' => path,
                  'SCRIPT_NAME' => path,
                  'PHP_SELF' => path,
                  'REQUEST_URI' => path + '?' + query,
                  'REQUEST_METHOD' => data.empty? ? 'GET' : 'POST',
                  'CONTENT_TYPE' => data.empty? ? '' : 'application/x-www-form-urlencoded',
                  'CONTENT_LENGTH' => data.length.to_s(10),
                  'RAW_POST_DATA' => data,
                  'QUERY_STRING' => query,
                  'SERVER_PROTOCOL' => 'HTTP/1.1',
                  'REMOTE_ADDR' => ip,
                  'REMOTE_PORT' => '52056',
                  'SERVER_ADDR' => ip,
                  'SERVER_PORT' => port,
                  'SERVER_NAME' => host,
                  'REDIRECT_STATUS' => "CGI",
                  'HTTP_HOST' => "#{host}:#{port}",
                  'HTTP_COOKIE' => cookie
    end
    b.run_action(:run)
  
    # parse headers from php-cgi results
    headers = []
    redirect = false
    IO.foreach(session_tmp.path) do |s|
      s = s.gsub(/[\r\n]/, '')
      if s.empty? then
        break
      end
      headers += s.scan(/(\S+): ([^\r\n]+)/)
    end
    headers.each do |header|
      case header[0]
      when "Set-Cookie"
        session_cookie = header[1]
      when "Location"
        tmp = header[1].split('?', 2)
        path  = 0 < tmp.length ? tmp[0] : ''
        query = 1 < tmp.length ? tmp[1] : ''
        data = ""
        redirect = true
      end
    end

    if ! redirect then
      break
    end
  end

  # test, was piwik installed? 
  if w[:data].empty? then
    s = File.open(session_tmp.path).read
    if s.include?("login_form") then
      Chef::Log.info("piwik was installed")
      break
    else
      # Delete the configuration file, it is because Setup will fail
      file "#{home}/config/config.inc.php" do
        action :delete
      end
    end
  end

end
