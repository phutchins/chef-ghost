if node[:ghost][:db_client] == 'mysql'

  mysql2_chef_gem "mysql2" do
    action :install
  end

  if node[:ghost][:databag]
    databag = Chef::EncryptedDataBagItem.load(node[:ghost][:databag], node[:ghost][:databag_item], node[:ghost][:databag_secret])
    node.set_unless[:ghost][:db_admin_password] = databag['db_admin_password'] rescue nil
    node.set_unless[:ghost][:db_password] = databag['db_password'] rescue nil
  end

  mysql_service 'ghost' do
    port '3306'
    version '5.6'
    initial_root_password node[:ghost][:db_admin_password]
    action [:create, :start]
  end

  mysql_connection_info = {:socket => '/run/mysql-ghost/mysqld.sock', :username => node[:ghost][:db_admin_user], :password => node[:ghost][:db_admin_password]}
  mysql_database node[:ghost][:db_name] do
    connection mysql_connection_info
    action :create
  end

  mysql_database_user node[:ghost][:db_user] do
    connection mysql_connection_info
    password node[:ghost][:db_password]
    database_name node[:ghost][:db_name]
    host node[:ghost][:db_grant_host]
    privileges [:all]
    action :grant
  end

  mysql_database_user node[:ghost][:db_user] do
    connection mysql_connection_info
    password node[:ghost][:db_password]
    database_name node[:ghost][:db_name]
    host 'localhost'
    privileges [:all]
    action :grant
  end
end
