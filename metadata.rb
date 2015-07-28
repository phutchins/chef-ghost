name             'ghost'
maintainer       'Rackspace'
maintainer_email 'ryan.walker@rackspace.com'
license          'Apache 2.0'
description      'Installs/Configures Ghost CMS'
version          '0.0.4'

%w{ database firewall git sqlite nginx nvm }.each do |cb|
  depends cb
end
