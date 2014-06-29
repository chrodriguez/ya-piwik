name             'ya-piwik'
maintainer       'sharkpp'
maintainer_email 'webmaster@sharkpp.net'
license          'The MIT License'
description      'Installs/Configures ya-piwik'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'
supports         'CentOS', ">= 6.0"

depends          'nginx'
depends          'php'
conflicts        'piwik'
