#
# Cookbook Name:: ya-piwik
# Libraries:: piwik_api
#
# Copyright 2014, sharkpp
#
# The MIT License
#

module YaPiwik

  class API
    attr_reader :token, :result

    def initialize(run_context = nil)
      raise 'Chef::RunContext not present!' unless run_context.is_a?(Chef::RunContext)

      @run_context = run_context
      @token = ''
      @result = []
    end

    def get_token(username = 'root')
      node = @run_context.node
      # build sql commandline
      token_cmdline = [
        "mysql -B -r",
              "-u \"#{node['ya-piwik']['database']['user']}\"",
              "--password='#{node['ya-piwik']['database']['pass']}'",
              "--execute='SELECT \`token_auth\`",
                         "FROM \`#{node['ya-piwik']['database']['prefix']}user\`",
                         "WHERE \`login\` = \"#{username}\"'",
              "\"#{node['ya-piwik']['database']['name']}\"",
        "| grep -v token_auth" ]
      # call and get auth token
      @token = `#{token_cmdline.join(" ")}`.chomp
    end

    def call(method = '', param)
      node = @run_context.node
      # get auht token if not present
      if @token.empty? then
        get_token(node['ya-piwik']['root']['user'])
      end

      param = param.delete_if {|x| /^(format|module|method|token_auth)=.*/ =~ x}
      param += [ "module=API" ]
      param += [ "method=#{method}" ]
      param += [ "token_auth=#{@token}" ]
      param += [ "format=JSON" ]

      ctx = PhpHeadlessBrowser::Context.new(@run_context)
      ctx.cwd = node['ya-piwik']['home']
      PhpHeadlessBrowser.run(ctx, 'index.php', param)

      @result = JSON.parse(ctx.response[:body]) rescue []
      @result
    end

    # call SitesManager.getSitesIdFromSiteUrl API
    def site_id_from_site_url(url)
        result = call('SitesManager.getSitesIdFromSiteUrl',
                      [ "url=#{url}" ])
        return result[0]["idsite"] rescue 0
    end

  end

end
