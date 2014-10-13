#
# Cookbook Name:: ya-piwik
# Libraries:: php_headless_browser
#
# Copyright 2014, sharkpp
#
# The MIT License
#

module YaPiwik
  module PhpHeadlessBrowser

    class Context
      attr_accessor :run_context
      attr_accessor :cwd, :user, :group, :max_redirect
      attr_accessor :response, :cookie

      def initialize(run_context = nil)
        raise 'Chef::RunContext not present!' unless run_context.is_a?(Chef::RunContext)
        @run_context = run_context
        @cwd   = '/var/www/html/'
        @user  = nil
        @group = nil
        @max_redirect = 10 # maximum 10 redirect support
        @response = { :body => '', :headers => [] }
        @cookie = ''
      end

      def reset_session()
        @cookie = ''
      end
    end

    def run(ctx, path, query = [], data = [], headers = {})
      raise 'Invalid argument, ctx'     unless ctx.is_a?(Context)
      raise 'Invalid argument, query'   unless query.is_a?(Array) or query.is_a?(String)
      raise 'Invalid argument, data'    unless data.is_a?(Array) or data.is_a?(String)
      raise 'Invalid argument, headers' unless headers.is_a?(Hash)

      session_tmp = Tempfile.new('session')

      query_ = query.is_a?(String) ? query : query.join("&")
      data_  = data.is_a?(String)  ? data  : data.join("&")

      i = 0
      while i < ctx.max_redirect && 0 < ctx.max_redirect
        i += 1

        path_  = '/piwik/'
        realpath= 'index.php'
        ip     = '127.0.0.1'
        host   = 'localhost'
        port   = '80'

        Chef::Log.debug("[YaPiwik::PhpHeadlessBrowser]: request:path='#{path_}'")
        Chef::Log.debug("[YaPiwik::PhpHeadlessBrowser]: request:query='#{query_}'")
        Chef::Log.debug("[YaPiwik::PhpHeadlessBrowser]: request:data='#{data_}'")
        Chef::Log.debug("[YaPiwik::PhpHeadlessBrowser]: request:cookie='#{ctx.cookie}'")

        # execute php-cgi
        bash = Chef::Resource::Script::Bash.new('execute php-cgi', ctx.run_context)
        bash.cwd ctx.cwd
        bash.user ctx.user ? ctx.user : bash.user
        bash.group ctx.group ? ctx.group : bash.group
        bash.code <<-EOH
          echo '#{data_}' | php-cgi > "#{session_tmp.path}"
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
                         'HTTP_HOST' => headers.has_key?(:host) ? headers[:host] : "#{host}:#{port}",
                         'HTTP_COOKIE' => ctx.cookie,
                         'HTTP_REFERER' => headers.has_key?(:referer) ? headers[:referer] : '',
                         'HTTP_USER_AGENT' => headers.has_key?(:user_agent) ? headers[:user_agent] : 'php5'
#        begin
            bash.run_action(:run)
#        rescue Mixlib::ShellOut::ShellCommandFailed
#            bash.user nil
#            bash.group nil
#            bash.code <<-EOH
#              prm1="#{ctx.user ? '-u ' + ctx.user : ''}"
#              prm2="#{ctx.group ? '-g ' + ctx.group : ''}"
#              if [ -n "$prm1" -o -n "$prm2" ] ; then
#                  echo '#{data_}' | sudo $prm1 $prm2 -n -- php-cgi > "#{session_tmp.path}"
#              fi
#            EOH
#            bash.run_action(:run)
#        end

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

        Chef::Log.debug("[YaPiwik::PhpHeadlessBrowser]: response:header=#{ctx.response[:headers]}")
        Chef::Log.debug("[YaPiwik::PhpHeadlessBrowser]: response:cookie='#{ctx.cookie}'")
        Chef::Log.debug("[YaPiwik::PhpHeadlessBrowser]: response:body='#{ctx.response[:body][0,256]}'")

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
