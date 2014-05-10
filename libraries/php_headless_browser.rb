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
      attr_accessor :run_context
      attr_accessor :cwd, :max_redirect
      attr_accessor :response, :cookie
      def initialize(run_context = nil)
        raise 'Chef::RunContext not present!' unless run_context.is_a?(Chef::RunContext)
        @run_context = run_context
        @cwd = '/var/www/html/'
        @max_redirect = 10 # maximum 10 redirect support
        @response = { :body => '', :headers => [] }
        @cookie = ''
      end
    end

    def run(ctx, path, query = [], data = [])
      raise 'Context not present!' unless ctx.is_a?(Context)

      p "________________________________________"
      p path
      p query
      p data
      p ctx.cookie

      session_tmp = Tempfile.new('session')

      query_ = query.join("&")
      data_  = data.join("&")

      i = 0
      while i < ctx.max_redirect && 0 < ctx.max_redirect
        i += 1

        path_  = '/piwik/'
        realpath= 'index.php'
        ip     = '127.0.0.1'
        host   = 'localhost'
        port   = '80'

        # execute php-cgi
        bash = Chef::Resource::Script::Bash.new('execute php-cgi', ctx.run_context)
        bash.cwd ctx.cwd
        bash.code <<-EOH
#         echo "**************** path=#{path_}"
#         echo "**************** query=#{query_}"
#         echo "**************** data=#{data_}"
#         echo "**************** cookie=#{ctx.cookie}"
          echo '#{data_}' | php-cgi > "#{session_tmp.path}"
#         cat "#{session_tmp.path}" | head -n 20
        EOH
        bash.environment 'DOCUMENT_ROOT' => ctx.cwd,
                         'HOME' => ctx.cwd,
                         'SCRIPT_FILENAME' => realpath,
                         'DOCUMENT_URI' => path_,
                         'SCRIPT_NAME' => path_,
                         'PHP_SELF' => path_,
                         'REQUEST_URI' => path_ + '?' + query_,
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

        # get request response
        response = File.open(session_tmp.path).read

        # parse headers and body from php-cgi results
        ctx.response = { :body => '', :headers => [] }
        redirect = false
        header_reading = true
        response.lines do |s|
          if header_reading then
            header_reading = ! s.chomp.empty?
            if header_reading then
              ctx.response[:headers] += s.chomp.scan(/(\S+): ([^\r\n]+)/)
            end
          else
            ctx.response[:body] += s
          end
        end

        # check header and ...
        ctx.response[:headers].each do |header|
          case header[0]
          when "Set-Cookie"
            ctx.cookie = header[1]
          when "Location"
            tmp = header[1].split('?', 2)
            path_  = 0 < tmp.length ? tmp[0] : ''
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
