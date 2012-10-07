#
# Cookbook Name:: phpmyadmin
# Provider:: pmadb
#
# Copyright 2012, Panagiotis Papadomitsos
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

action :create do
	Chef::Log.info("Creating PHPMyAdmin control database for: #{new_resource.name}")
	new_resource.updated_by_last_action(false)

	template "#{Chef::Config['file_cache_path']}/phpmyadmin.sql" do
		source "phpmyadmin.sql.erb"
		owner "root"
		group "root"
		mode 00644
		variables({
			:pma_db => new_resource.pma_database,
			:pma_user => new_resource.pma_username,
			:pma_pass => new_resource.pma_password
		})
		action :create
		notifies :run, "execute[create-pma-database-for-#{new_resource.name}]"
	end
	
	execute "create-pma-database-for-#{new_resource.name}" do
		user "root"
		group "root"
		cwd Chef::Config['file_cache_path']
		command %Q{ mysql -u#{new_resource.root_username} -p#{new_resource.root_password} -h#{new_resource.host} -P#{new_resource.port} < #{Chef::Config['file_cache_path']}/phpmyadmin.sql }
		action :nothing
	end

	ruby_block "phpmyadmin-create-control-#{new_resource.name}" do
		block do
			new_resource.updated_by_last_action(true)
		end
		action :nothing
		subscribes :create, "execute[create-pma-database-for-#{new_resource.name}]"
	end	
end

action :delete do
	Chef::Log.info("Removing PHPMyAdmin control database for: #{new_resource.name}")
	new_resource.updated_by_last_action(false)

	execute "drop-pma-user-for-#{new_resource.name}" do
		command %Q{ mysql -u#{new_resource.root_username} -p#{new_resource.root_password} -h#{new_resource.host} -P#{new_resource.port} -e 'DELETE FROM `mysql`.`user` WHERE `User` = "#{new_resource.pma_username}"' }
		not_if %Q{ mysql -u#{new_resource.root_username} -p#{new_resource.root_password} -h#{new_resource.host} -P#{new_resource.port} -e 'SHOW GRANTS FOR "#{new_resource.pma_username}"@"%"' }
		action :run
		notifies :run, "execute[drop-pma-database-for-#{new_resource.name}]"
	end

	execute "drop-pma-database-for-#{new_resource.name}" do
		command %Q{ mysql -u#{new_resource.root_username} -p#{new_resource.root_password} -h#{new_resource.host} -P#{new_resource.port} -e 'DROP DATABASE #{new_resource.pma_database}' }
		not_if %Q{ mysql -u#{new_resource.root_username} -p#{new_resource.root_password} -h#{new_resource.host} -P#{new_resource.port} -e 'SHOW DATABASES LIKE "#{new_resource.pma_database}"' }
		action :nothing
	end

	ruby_block "phpmyadmin-remove-control-#{new_resource.name}" do
		block do
			new_resource.updated_by_last_action(true)
		end
		action :nothing
		subscribes :create, "execute[drop-pma-database-for-#{new_resource.name}]"
	end	
end