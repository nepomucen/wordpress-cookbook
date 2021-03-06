#
# Cookbook Name:: wordpress
# Recipe:: database
# Author:: Lucas Hansen (<lucash@opscode.com>)
# Author:: Julian C. Dunn (<jdunn@getchef.com>)
#
# Copyright (C) 2013, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

mysql_client 'default' do
  action :create
  not_if { node['platform_family'] == 'windows' }
end

mysql_service 'wordpress' do
  port '3306'
  version '5.5'
  initial_root_password node['mysql']['server_root_password']
  action [:create, :start]
end

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['wordpress']['db']['pass'] = secure_password
node.save unless Chef::Config[:solo]

::Chef::Recipe.send(:include, Wordpress::Helpers)

db = node['wordpress']['db']

if is_local_host? db['host']

  mysql_bin = (platform_family? 'windows') ? 'mysql.exe' : 'mysql'
  user = "'#{db['user']}'@'#{db['host']}'"
  create_user = %<CREATE USER #{user} IDENTIFIED BY '#{db['pass']}';>
  user_exists = %<SELECT 1 FROM mysql.user WHERE user = '#{db['user']}';>
  create_db = %<CREATE DATABASE #{db['name']};>
  db_exists = %<SHOW DATABASES LIKE '#{db['name']}';>
  grant_privileges = %<GRANT ALL PRIVILEGES ON #{db['name']}.* TO #{user};>
  privileges_exist = %<SHOW GRANTS FOR for #{user}@'%';>
  flush_privileges = %<FLUSH PRIVILEGES;>

  execute "Create WordPress MySQL User" do
    action :run
    command "#{mysql_bin} #{::Wordpress::Helpers.make_db_query("root", node['mysql']['server_root_password'], db['host'], create_user)}"
    only_if { `#{mysql_bin} #{::Wordpress::Helpers.make_db_query("root", node['mysql']['server_root_password'], db['host'], user_exists)}`.empty? }
  end

  execute "Grant WordPress MySQL Privileges" do
    action :run
    command "#{mysql_bin} #{::Wordpress::Helpers.make_db_query("root", node['mysql']['server_root_password'], db['host'], grant_privileges)}"
    only_if { `#{mysql_bin} #{::Wordpress::Helpers.make_db_query("root", node['mysql']['server_root_password'], db['host'], privileges_exist)}`.empty? }
    notifies :run, "execute[Flush MySQL Privileges]"
  end

  execute "Flush MySQL Privileges" do
    action :nothing
    command "#{mysql_bin} #{::Wordpress::Helpers.make_db_query("root", node['mysql']['server_root_password'], db['host'], flush_privileges)}"
  end

  execute "Create WordPress Database" do
    action :run
    command "#{mysql_bin} #{::Wordpress::Helpers.make_db_query("root", node['mysql']['server_root_password'], db['host'], create_db)}"
    only_if { `#{mysql_bin} #{::Wordpress::Helpers.make_db_query("root", node['mysql']['server_root_password'], db['host'], db_exists)}`.empty? }
  end
end