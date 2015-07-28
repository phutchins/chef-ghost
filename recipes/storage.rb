storage_path = node[:ghost][:storage][:path]

if node[:ghost][:storage][:location] != 'ghost'
  directory storage_path do
    user node[:ghost][:user]
    group node[:ghost][:user]
    action :create
  end

  case node[:ghost][:storage][:location]
  when 's3'
    cookbook_file File.join(storage_path, 'storage_s3.js') do
      user node[:ghost][:user]
      group node[:ghost][:user]
      action :create
    end
  end
end
