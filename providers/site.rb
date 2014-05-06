#
# Cookbook Name:: ya-piwik
# Provider:: ya_piwik_site
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

require 'json'

action :create do
  Chef::Log.info("Creating piwik site configuration for: #{new_resource.siteName}")

  # get auth_token from root user
  token_cmdline = [
    "mysql -B -r",
          "-u \"#{node['ya-piwik']['database']['user']}\"",
          "--password='#{node['ya-piwik']['database']['pass']}'",
          "--execute='SELECT \`token_auth\`",
                     "FROM \`#{node['ya-piwik']['database']['prefix']}user\`",
                     "WHERE \`login\` = \"root\"'",
          "\"#{node['ya-piwik']['database']['name']}\"",
    "| grep -v token_auth" ]
  token = `#{token_cmdline.join(" ")}`
  token = token.sub(/[\r\n]/, '')

  session_tmp = Tempfile.new('session')
  session_cookie = ''
  idsite = new_resource.idsite
  urls = new_resource.urls
  urls = [ urls ] if urls.instance_of?(String)

  [
    { :path => 'index.php', :query => [ "module=API",
                                        "method=SitesManager.getSitesIdFromSiteUrl",
                                        "url=#{new_resource.urls[0]}",
                                        "format=JSON",
                                        "token_auth=#{token}" ], :data => [ ] },
    { :path => 'index.php', :query => [ "module=API",
                                        "method=SitesManager.addSite",
                                        "siteName=#{new_resource.siteName}",
                                        "urls[0]=",
                                        "timezone=#{new_resource.timezone}",
                                        "ecommerce=#{new_resource.ecommerce}",
                                        "format=JSON",
                                        "token_auth=#{token}" ], :data => [ ] }

  ].each do |w|

    query = w[:query].join("&")
    data  = w[:data].join("&")

    # do not get 'idsite' if is specified in advance
    if query.include?("SitesManager.getSitesIdFromSiteUrl") && 0 < idsite then
      Chef::Log.debug("piwik idsite was already specified: #{idsite.to_s}")
      next
    end

    if query.include?("SitesManager.addSite") then
      # change 'add' to 'update' if idsite valid
      if 0 < idsite then
        query = query.sub(".addSite", ".updateSite")
        query+= "&idSite=#{idsite.to_s}"
      end
      # set urls
      urls_ = []
      i = 0
      urls.each do |url|
        urls_ += [ "urls[#{i.to_s}]=#{url}" ]
        i += 1
      end
      query = query.sub("urls[0]=", urls_.join("&"))
    end

    for i in (1..5).to_a # maximum 5 redirect support
  
      # execute php-cgi
      b = bash "call php-cgi" do
    
        cwd_   = node['ya-piwik']['home']
        path   = '/piwik/'
        realpath= 'index.php'
        ip     = '127.0.0.1'
        host   = 'localhost'
        port   = '80'
        cookie = session_cookie

        cwd cwd_
        code <<-EOH
#         echo "**************** path=#{path}"
#         echo "**************** query=#{query}"
#         echo "**************** data=#{data}"
#         echo "**************** cookie=#{cookie}"
          echo '#{data}' | php-cgi > "#{session_tmp.path}"
#         cat "#{session_tmp.path}" | head -n 20
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

    header_reading = true
    body = ''
    IO.foreach(session_tmp.path) do |s|
      s = s.gsub(/[\r\n]/, '')
      p s
      if header_reading then
        header_reading = ! s.empty?
        next
      end
      body += s
    end
    api_result = JSON.parse(body) rescue [];

    # _
    case w[:query][1]
    when "method=SitesManager.getSitesIdFromSiteUrl"
      idsite = api_result[0]['idsite']
    end

  end

  new_resource.updated_by_last_action(true)
end
