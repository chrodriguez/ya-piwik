#
# Cookbook Name:: ya-piwik
# Provider:: ya_piwik_site
#
# Copyright 2014, sharkpp
#
# The MIT License
#

require 'json'

action :create do
  Chef::Log.info("Creating piwik site configuration for: #{new_resource.siteName}")

  ctx = PhpHeadlessBrowser::Context.new(node.run_context)
  ctx.cwd = node['ya-piwik']['home']

  # get auth_token from root user
  token_cmdline = [
    "mysql -B -r",
          "-u \"#{node['ya-piwik']['database']['user']}\"",
          "--password='#{node['ya-piwik']['database']['pass']}'",
          "--execute='SELECT \`token_auth\`",
                     "FROM \`#{node['ya-piwik']['database']['prefix']}user\`",
                     "WHERE \`login\` = \"#{node['ya-piwik']['root']['user']}\"'",
          "\"#{node['ya-piwik']['database']['name']}\"",
    "| grep -v token_auth" ]
  token = `#{token_cmdline.join(" ")}`
  token = token.chomp

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
                                        "timezone=#{new_resource.timezone}",
                                        "ecommerce=#{new_resource.ecommerce}",
                                        "format=JSON",
                                        "token_auth=#{token}" ], :data => [ ] }

  ].each do |w|

    # do not get 'idsite' if is specified in advance
    if w[:query][1].include?("SitesManager.getSitesIdFromSiteUrl") && 0 < idsite then
      Chef::Log.debug("piwik idsite was already specified: #{idsite.to_s}")
      next
    end

    if w[:query][1].include?("SitesManager.addSite") then
      # change 'add' to 'update' if idsite valid
      if 0 < idsite then
        w[:query][1] = w[:query][1].sub(".addSite", ".updateSite")
        w[:query]   += [ "idSite=#{idsite.to_s}" ]
      end
      # set urls
      urls_ = []
      i = 0
      urls.each do |url|
        w[:query] += [ "urls[#{i.to_s}]=#{url}" ]
        i += 1
      end
    end

    PhpHeadlessBrowser.run(ctx, w[:path], w[:query], w[:data])

    api_result = JSON.parse(ctx.response[:body]) rescue [];

    # set siteid
    case w[:query][1]
    when "method=SitesManager.getSitesIdFromSiteUrl"
      idsite = api_result[0]['idsite']
    end

  end

  new_resource.updated_by_last_action(true)
end
