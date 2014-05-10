#
# Cookbook Name:: ya-piwik
# Attribute:: default
#
# Copyright 2014, sharkpp
#
# The MIT License
#

module YaPiwik
  module PhpHeadlessBrowser

    class Context
      attr_accessor :cookie
      class << self
        def initialize
          @cookie = ''
        end
      end
    end

    def run(ctx, url, query = [], data = [])
      raise 'Context not present!' unless ctx.is_a?(Context)
      p "________________________________________"
      p url
      p query
      p data

      session_tmp = Tempfile.new('session')

      query_ = query.join("&")
      data_  = data.join("&")
    
      for i in (1..5).to_a # maximum 5 redirect support

        cwd_   = '/var/www/html/piwik/'
        path   = '/piwik/'
        realpath= 'index.php'
        ip     = '127.0.0.1'
        host   = 'localhost'
        port   = '80'

        # execute php-cgi
#        node = Chef::Node.new
node=nil
        run_context = Chef::RunContext.new(node, {}, nil)
        bash = Chef::Resource::Script::Bash.new('execute php-cgi', run_context)
        bash.cwd cwd_
        bash.code <<-EOH
          echo "**************** path=#{path}"
          echo "**************** query=#{query_}"
          echo "**************** data=#{data_}"
          echo "**************** cookie=#{ctx.cookie}"
           echo '#{data_}' | php-cgi > "#{session_tmp.path}"
           cat "#{session_tmp.path}" | head -n 20
        EOH
        bash.environment 'DOCUMENT_ROOT' => cwd_,
                         'HOME' => cwd_,
                         'SCRIPT_FILENAME' => realpath,
                         'DOCUMENT_URI' => path,
                         'SCRIPT_NAME' => path,
                         'PHP_SELF' => path,
                         'REQUEST_URI' => path + '?' + query_,
                         'REQUEST_METHOD' => data_.empty? ? 'GET' : 'POST',
                         'CONTENT_TYPE' => data_.empty? ? '' : 'application/x-www-form-urlencoded',
                         'CONTENT_LENGTH' => data_.length.to_s(10),
                         'RAW_POST_DATA' => data_,
                         'QUERY_STRING' => query_,
                         'SERVER_PROTOCOL' => 'HTTP/1.1',
                         'REMOTE_ADDR' => ip,
                         'REMOTE_PORT' => '52056',
                         'SERVER_ADDR' => ip,
                         'SERVER_PORT' => port,
                         'SERVER_NAME' => host,
                         'REDIRECT_STATUS' => "CGI",
                         'HTTP_HOST' => "#{host}:#{port}",
                         'HTTP_COOKIE' => ctx.cookie
        bash.run_action(:run)

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
            ctx.cookie = header[1]
          when "Location"
            tmp = header[1].split('?', 2)
            path   = 0 < tmp.length ? tmp[0] : ''
            query_ = 1 < tmp.length ? tmp[1] : ''
            data_  = ""
            redirect = true
          end
        end

        if ! redirect then
          break
        end
      end
    end

    module_function :run
  end
end

#Chef::Recipe.send(:include,   ::YaPiwik::PhpHeadlessBrowser)
#Chef::Resource.send(:include, ::YaPiwik::PhpHeadlessBrowser)
#Chef::Provider.send(:include, ::YaPiwik::PhpHeadlessBrowser)
Chef::Recipe.send(:include,   ::YaPiwik)
Chef::Resource.send(:include, ::YaPiwik)
Chef::Provider.send(:include, ::YaPiwik)
