# frozen_string_literal: true

name              'noderings'
maintainer        'NodeRings'
maintainer_email  'partners@noderings.com'
license           'Apache-2.0'
description       'Resources to manage NodeRings virtual machines, DNS zones and records, firewall rulesets and SSH keys'
version           '0.1.1' # x-release-please-version
source_url        'https://github.com/noderings/noderings-cookbook'
issues_url        'https://github.com/noderings/noderings-cookbook/issues'
chef_version      '>= 17'

%w(
  almalinux amazon centos centos_stream debian fedora mac_os_x opensuseleap oracle
  redhat rocky ubuntu windows
).each do |os|
  supports os
end
