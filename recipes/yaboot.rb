# Author:: Matt Ray <matt@opscode.com>
# Cookbook Name:: pxe_dust
# Recipe:: yaboot
#
# Copyright 2013 Opscode, Inc
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

include_recipe 'pxe_dust::server'

#search for any apt-cacher-ng caching proxies
if Chef::Config[:solo]
  Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  proxy = '#d-i mirror/http/proxy string url'
else
  query = "apt_caching_server:true"
  query += " AND chef_environment:#{node.chef_environment}" if node['apt']['cacher-client']['restrict_environment']
  Chef::Log.debug("pxe_dust::server searching for '#{query}'")
  servers = search(:node, query) || []
  if servers.length > 0
    if servers[0]['apt']['cacher_interface']
      cacher_ipaddress = interface_ipaddress(servers[0], node['apt']['cacher_interface'])
    else
      cacher_ipaddress = servers[0].ipaddress
    end
    proxy = "d-i mirror/http/proxy string http://#{cacher_ipaddress}:#{servers[0]['apt']['cacher_port']}"
  else
    proxy = '#d-i mirror/http/proxy string url'
  end
end

if node['pxe_dust']['interface']
  server_ipaddress = interface_ipaddress(node, node['pxe_dust']['interface'])
else
  server_ipaddress = node.ipaddress
end
server_ipaddress += ":#{node['pxe_dust']['port']}"

# loop over the other data bag items here
begin
  default = node['pxe_dust']['default']
  pxe_dust = data_bag('pxe_dust')
  default = data_bag_item('pxe_dust', 'default').merge(default)
rescue
  Chef::Log.warn("No 'pxe_dust' data bag found.")
  pxe_dust = []
end

pxe_dust.each do |id|
  image_dir = "#{node['dnsmasq']['dhcp']['tftp-root']}/#{id}"
  # override the defaults with the image values, then override those with node values
  image = default.merge(data_bag_item('pxe_dust', id)).merge(node['pxe_dust']['default'])

  platform = image['platform']
  arch = image['arch']
  version = image['version']

  if arch.eql?('ppc') #skip it otherwise
    if image['user']
      user_fullname = image['user']['fullname']
      user_username = image['user']['username']
      user_crypted_password = image['user']['crypted_password']
    end
    if image['root']
      root_crypted_password = image['root']['crypted_password']
    end

    #local mirror for ppc mini ISO
    remote_file "#{node['pxe_dust']['dir']}/isos/#{platform}-#{version}-#{arch}-mini.iso" do
      source image['netboot_url']
      action :create_if_missing
    end

    directory "#{image_dir}" do
      owner node['dnsmasq']['user']
      mode 0755
      recursive true
    end

    # target dir
    directory "#{image_dir}/iso" do
      mode 0755
      recursive true
    end

    # mount iso at target
    mount "mount the iso"  do
      mount_point "#{image_dir}/iso"
      device "#{node['pxe_dust']['dir']}/isos/#{platform}-#{version}-#{arch}-mini.iso"
      options 'loop'
      action :mount
    end

    # populate the target with iso/install contents
    ['boot.msg', 'netboot-initrd.gz', 'netboot-linux'].each do |ifile|
      execute "cp #{image_dir}/iso/install/#{ifile} #{image_dir}/#{ifile}" do
        user node['dnsmasq']['user']
        not_if { File.exists?("#{image_dir}/#{ifile}") }
      end
    end

    # get the yaboot
    execute "cp #{image_dir}/iso/install/yaboot #{node['dnsmasq']['dhcp']['tftp-root']}/yaboot" do
      user node['dnsmasq']['user']
      not_if { File.exists?("#{node['dnsmasq']['dhcp']['tftp-root']}/yaboot") }
    end

    # umount iso
    mount "umount the iso"  do
      mount_point "#{image_dir}/iso"
      device "#{node['pxe_dust']['dir']}/isos/#{platform}-#{version}-#{arch}-mini.iso"
      action :umount
    end

    # template the yaboot.conf
    if image['addresses']
      image['addresses'].keys.each do |mac_address|
        mac = mac_address.gsub(/:/, '-')
        mac.downcase!
        template "#{node['dnsmasq']['dhcp']['tftp-root']}/yaboot.conf" do
          source 'yaboot.conf.erb'
          owner node['dnsmasq']['user']
          mode 0644
          variables(
            :server_ipaddress => server_ipaddress,
            :interface => image['interface'] || 'eth0',
            :id => id,
            :domain => image['domain'],
            :hostname => image['addresses'][mac_address],
            :preseed => image['external_preseed'].nil? ? "#{id}-preseed.cfg" : image['external_preseed']
            )
        end
      end
    end

    # preseed
    template "#{node['pxe_dust']['dir']}/#{id}-preseed.cfg" do
      only_if { image['external_preseed'].nil? }
      source "#{platform}-preseed.cfg.erb"
      mode 0644
      variables(
        :server_ipaddress => server_ipaddress,
        :id => id,
        :proxy => proxy,
        :boot_volume_size => image['boot_volume_size'] || '30GB',
        :packages => image['packages'] || '',
        :user_fullname => user_fullname,
        :user_username => user_username,
        :user_crypted_password => user_crypted_password,
        :root_crypted_password => root_crypted_password,
        :halt => image['halt'] || false,
        :bootstrap => image['chef'] || true
        )
    end

  end
end
