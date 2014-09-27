ya-piwik cookbook [![Build Status](https://travis-ci.org/sharkpp-cookbooks/ya-piwik.svg?branch=master)](https://travis-ci.org/sharkpp-cookbooks/ya-piwik)
=================

This cookbook is install and management for piwik.

ya-piwik is an abbreviation for Yet Another Piwik.

Now, this cookbook you can in the following list:

* install piwik
* site management (create and update)

Requirements
============

## Environment 

- MySQL - piwik needs MySQL server

## Cookbooks

- `php` - ya-piwik needs php.
- `nginx` - ya-piwik needs nginx if `node['ya-piwik']['fpm']['enable']` was `true`.

## Operating Systems

* CentOS 6.0 or later

Attributes
==========

## `ya-piwik::default`

<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['home']</tt></td>
    <td>String</td>
    <td>piwik install directory</td>
    <td><tt>'/var/www/html/piwik/'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['package']</tt></td>
    <td>String</td>
    <td>piwik package url</td>
    <td><tt>'http://builds.piwik.org/piwik-latest.tar.gz'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['fpm']['enable']</tt></td>
    <td>Boolean</td>
    <td>php-fpm enable <strong>(required <a href="https://github.com/priestjim/chef-php">php</a> cookbook)</strong></td>
    <td><tt>true</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['fpm']['user']</tt></td>
    <td>String</td>
    <td>php-fpm usarname</td>
    <td><tt>true</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['fpm']['group']</tt></td>
    <td>String</td>
    <td>php-fpm group</td>
    <td><tt>''</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['fpm']['socket']</tt></td>
    <td>String</td>
    <td>php-fpm socket name</td>
    <td><tt>'/var/run/php-fpm/piwik.php-fpm.sock'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['database']['host']</tt></td>
    <td>String</td>
    <td>database server host name</td>
    <td><tt>'127.0.0.1'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['database']['user']</tt></td>
    <td>String</td>
    <td>database user name</td>
    <td><tt>'root'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['database']['pass']</tt></td>
    <td>String</td>
    <td>database password</td>
    <td><tt>'secret-password-here'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['database']['name']</tt></td>
    <td>String</td>
    <td>database name</td>
    <td><tt>'piwik'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['database']['prefix']</tt></td>
    <td>String</td>
    <td>database table prefix</td>
    <td><tt>''</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['database']['adapter']</tt></td>
    <td>String</td>
    <td>database adapter <tt>'MYSQL'</tt> or <tt>'MYSQLI'</tt></td>
    <td><tt>'MYSQLI'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['root']['user']</tt></td>
    <td>String</td>
    <td>username of root user</td>
    <td><tt>'root'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['root']['pass']</tt></td>
    <td>String</td>
    <td>password of root user</td>
    <td><tt>'secret-password-here'</tt></td>
  </tr>
  <tr>
    <td><tt>['ya-piwik']['root']['email']</tt></td>
    <td>String</td>
    <td>email of root user</td>
    <td><tt>'piwik@example.net'</tt></td>
  </tr>
</table>

LWRP
====

## `ya_piwik_site`

this LWRP is create new or overwrite site to piwik.


### Actions

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
  </tr>
  <tr>
    <td><tt>:create</tt></td>
    <td>create site configuration</td>
  </tr>
</table>

### Parameters

<table>
  <tr>
    <th>Name</th>
    <th>Type</th>
    <th>Required</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>idsite</tt></td>
    <td>Fixnum</td>
    <td>false</td>
    <td>site id of site</td>
    <td><tt>0</tt></td>
  </tr>
  <tr>
    <td><tt>siteName</tt></td>
    <td>String</td>
    <td>true</td>
    <td>site name of new site</td>
    <td><tt> </tt></td>
  </tr>
  <tr>
    <td><tt>urls</tt></td>
    <td>String | String of Array</td>
    <td>true</td>
    <td>url of new site, Overwrite the site that matches the URL if not <tt>idsite</tt> specified</td>
    <td><tt> </tt></td>
  </tr>
  <tr>
    <td><tt>timezone</tt></td>
    <td>String</td>
    <td>false</td>
    <td>timezone of new site</td>
    <td><tt>'Asia/Tokyo'</tt></td>
  </tr>
  <tr>
    <td><tt>ecommerce</tt></td>
    <td>String</td>
    <td>false</td>
    <td>promote e-commerce of new site</td>
    <td><tt>'0'</tt></td>
  </tr>
</table>

### Example

```
ya_piwik_site 'make piwik main site' do
  idsite 1
  siteName 'My blog'
  urls 'http://blog.example.net/'
  action :create
end
```

Libraries
=========

YaPiwik::API class is call piwik API helper.

### Example

```
  api = YaPiwik::API.new(node.run_context)
  idsite = api.site_id_from_site_url('http://blog.example.net/') # idsite => 1
```

Usage
=====

## `ya-piwik::default`

Just include `ya-piwik` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[ya-piwik]"
  ]
}
```

Testing
=======

1. Fork the repository on Github
2. `bundle install --path vendor/bundle`
3. `bundle ex kitchen test`

Contributing
============

1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
===================

Copyright (c) 2014 sharkpp

This cookbook is under The MIT License.

Full license text, please refer to the `LICENSE`.
