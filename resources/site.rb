#
# Cookbook Name:: ya-piwik
# Resource:: ya_piwik_site
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

default_action :create

actions :create

attribute :idsite,		:kind_of => Fixnum, :required => false, :default => 0
attribute :siteName,	:kind_of => String, :required => true
attribute :urls,		:kind_of => [ String, Array ], :required => true
attribute :timezone,	:kind_of => String, :required => false, :default => "Asia/Tokyo"
attribute :ecommerce,	:kind_of => String, :required => false, :default => "0"
