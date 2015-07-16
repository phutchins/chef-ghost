### Setup User and Install Directory
include_recipe "ghost::user"

directory node[:ghost][:install_path] do
  owner node[:ghost][:user]
  group node[:ghost][:user]
  mode "0755"
  recursive true
  action :create
end

### Setup NodeJS and NPM
include_recipe 'nvm'

nvm_install "install ghost nvm" do
  version '0.10.36'
  user node['ghost']['user']
  group node['ghost']['user']
  user_home node['ghost']['home_dir']
  from_source false
  alias_as_default true
  action :create
end

### Download and Extract Ghost Archive
include_recipe "ark"

%w[sqlite3 sqlite3-doc libsqlite3-dev].each do |pkg|
  package pkg do
    action :install
  end
end

ark 'ghost' do
  url node[:ghost][:src_url]
  path node[:ghost][:install_path]
  owner node[:ghost][:user]
  strip_leading_dir false
  action :put
end

extract_dir = ::File.join(node[:ghost][:install_path], "ghost")

### Work-around for bug in ark cookbook
bash "unzip_ghost" do
  cwd Chef::Config[:file_cache_path]
  code "unzip -q -u -o #{Chef::Config[:file_cache_path]}/ghost.zip -d #{extract_dir}"
  not_if do
    File.exists?("#{extract_dir}/config.js")
  end
end

### Install Dependencies
script "install_ghost" do
  interpreter 'bash'
  flags '-l'
  user node['ghost']['user']
  group node['ghost']['group']
  cwd extract_dir
  environment Hash[ 'HOME' => node['ghost']['home_dir'] ]
  code <<-EOH
    export NVM_DIR=#{node['ghost']['home_dir'] + '/.nvm'}
    #{node['nvm']['source']}
    npm install --production
  EOH
end

### Load Secrets from Databag
if node[:ghost][:databag]
  databag = Chef::EncryptedDataBagItem.load(node[:ghost][:databag], node[:ghost][:databag_item])
  node.set_unless[:ghost][:mail_password] = databag['ghost']['mail_password'] rescue nil
  node.set_unless[:ghost][:db_password] = databag[:ghost]['db_password'] rescue nil
end

### Create Config
template ::File.join(extract_dir, "config.js") do
  source "config.js.erb"
  owner node[:ghost][:user]
  group node[:ghost][:user]
  mode "0660"
  variables(
    :url		=> node[:ghost][:url],
    :mail_transport     => node[:ghost][:mail_transport].downcase,
    :mail_user  	=> node[:ghost][:mail_user],
    :mail_password 	=> node[:ghost][:mail_password],
    :node_env => node[:ghost][:node_env],
    :db_client => node[:ghost][:db_client],
    :db_host		=> node[:ghost][:db_host],
    :db_user		=> node[:ghost][:db_user],
    :db_password	=> node[:ghost][:db_password],
    :db_name		=> node[:ghost][:db_name],
    :db_sqlite3_path => node[:ghost][:sqlite3][:db_path]
  )
  action :nothing
end

### Install Themes
node[:ghost][:themes].each do |name,source_url|
  ghost_theme name do
    source source_url
  end
end

### Set File Ownership
bash "set_ownership" do
  cwd node[:ghost][:install_path]
  code "chown -R #{node[:ghost][:user]}:#{node[:ghost][:user]} #{node[:ghost][:install_path]}"
end

### Create log directory
directory node['ghost']['log_dir'] do
  user node['ghost']['user']
  action :create
end

### Create Service
case node[:platform]
when "ubuntu"
  if node["platform_version"].to_f >= 9.10
    template "/etc/init/ghost.conf" do
      source "ghost.conf.erb"
      mode "0644"
      variables(
        :user		=> node[:ghost][:user],
        :nvm_dir => node['ghost']['home_dir'] + '/.nvm',
        :node_env => node['ghost']['node_env'],
        :log_dir => node['ghost']['log_dir'],
        :dir		=> extract_dir
      )
    end
  end
end

service "ghost" do
  case node["platform"]
  when "ubuntu"
    if node["platform_version"].to_f >= 9.10
      provider Chef::Provider::Service::Upstart
    end
  end
  action [ :enable, :start ]
end
