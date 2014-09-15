# -*- coding:utf-8 -*-

require 'serverspec'
require 'pathname'

include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS

RSpec.configure do |c|
  c.before :all do
    c.os = backend(Serverspec::Commands::Base).check_os
    c.path = '/sbin:/usr/bin'
  end
end

describe port(80) do
  it { should be_listening }
end

describe file('/var/www/html/piwik/index.php') do
  it { should be_file }
end

describe file('/var/www/html/piwik/config/config.ini.php') do
  it { should be_file }
end
