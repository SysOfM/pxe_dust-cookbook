#
# Author:: Matt Ray <matt@opscode.com>
# Cookbook Name:: pxe_dust
# Attributes:: default
#
# Copyright 2011-2013 Opscode, Inc
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

default['pxe_dust']['chefversion'] = nil
default['pxe_dust']['default'] = {}
default['pxe_dust']['dir'] = '/var/www/pxe_dust'
default['pxe_dust']['hosts_file'] = '/etc/hosts_pxe_dust'
default['pxe_dust']['interface'] = nil
default['pxe_dust']['port'] = 9630
default['pxe_dust']['chef_server_url'] = Chef::Config[:chef_server_url]
default['pxe_dust']['validation_client_name'] = Chef::Config[:validation_client_name]
default['pxe_dust']['validation_key'] = Chef::Config[:validation_key]
