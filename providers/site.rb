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

  api = YaPiwik::API.new(node.run_context)

  idsite = new_resource.idsite
  urls = new_resource.urls
  urls = [ urls ] if urls.instance_of?(String)

  [
    { :method => 'SitesManager.getSitesIdFromSiteUrl',
      :param => [ "url=#{new_resource.urls[0]}" ] },
    { :method => 'SitesManager.addSite',
      :param => [ "siteName=#{new_resource.siteName}",
                  "timezone=#{new_resource.timezone}",
                  "ecommerce=#{new_resource.ecommerce}" ] }

  ].each do |w|

    case w[:method]
    when "SitesManager.getSitesIdFromSiteUrl"
      # do not get 'idsite' if is specified in advance
      if 0 < idsite then
        Chef::Log.debug("piwik idsite was already specified: #{idsite.to_s}")
        next
      end
    when "SitesManager.addSite"
      # change 'add' to 'update' if idsite valid
      if 0 < idsite then
        w[:method] = w[:method].sub(".addSite", ".updateSite")
        w[:param] += [ "idSite=#{idsite.to_s}" ]
      end
      # set urls
      urls_ = []
      i = 0
      urls.each do |url|
        w[:param] += [ "urls[#{i.to_s}]=#{url}" ]
        i += 1
      end
    end

    # call piwik api
    api_result = api.call(w[:method], w[:param])

    # set siteid
    case w[:method]
    when "SitesManager.getSitesIdFromSiteUrl"
      idsite = api_result[0]['idsite']
    end

  end

  new_resource.updated_by_last_action(true)
end
