require 'spec_helper'

describe 'neutron::server' do

  let :pre_condition do
    "class { 'neutron': rabbit_password => 'passw0rd' }"
  end

  let :params do
    { :auth_password => 'passw0rd',
      :auth_user     => 'neutron' }
  end

  let :default_params do
    { :package_ensure => 'present',
      :enabled        => true,
      :log_dir        => '/var/log/neutron',
      :auth_type      => 'keystone',
      :auth_host      => 'localhost',
      :auth_port      => '35357',
      :auth_tenant    => 'services',
      :auth_user      => 'neutron' }
  end

  shared_examples_for 'a neutron server' do
    let :p do
      default_params.merge(params)
    end

    it { should include_class('neutron::params') }
    it 'configures logging' do
      should contain_neutron_config('DEFAULT/log_file').with_ensure('absent')
      should contain_neutron_config('DEFAULT/log_dir').with_value(p[:log_dir])
    end

    it 'configures authentication middleware' do
      should contain_neutron_api_config('filter:authtoken/auth_host').with_value(p[:auth_host]);
      should contain_neutron_api_config('filter:authtoken/auth_port').with_value(p[:auth_port]);
      should contain_neutron_api_config('filter:authtoken/admin_tenant_name').with_value(p[:auth_tenant]);
      should contain_neutron_api_config('filter:authtoken/admin_user').with_value(p[:auth_user]);
      should contain_neutron_api_config('filter:authtoken/admin_password').with_value(p[:auth_password]);
      should contain_neutron_api_config('filter:authtoken/auth_admin_prefix').with(:ensure => 'absent')
    end

    it 'installs neutron server package' do
      if platform_params.has_key?(:server_package)
        should contain_package('neutron-server').with(
          :name   => platform_params[:server_package],
          :ensure => p[:package_ensure]
        )
        should contain_package('neutron-server').with_before(/Neutron_api_config\[.+\]/)
        should contain_package('neutron-server').with_before(/Neutron_config\[.+\]/)
        should contain_package('neutron-server').with_before(/Service\[neutron-server\]/)
      else
        should contain_package('neutron').with_before(/Neutron_api_config\[.+\]/)
      end
    end

    it 'configures neutron server service' do
      should contain_service('neutron-server').with(
        :name    => platform_params[:server_service],
        :enable  => true,
        :ensure  => 'running',
        :require => 'Class[Neutron]'
      )
      should contain_neutron_api_config('filter:authtoken/auth_admin_prefix').with(
        :ensure => 'absent'
      )
    end
  end

  shared_examples_for 'a neutron server with auth_admin_prefix set' do
    [ '/keystone', '/keystone/admin', '' ].each do |auth_admin_prefix|
      describe "with keystone_auth_admin_prefix containing incorrect value #{auth_admin_prefix}" do
        before do
          params.merge!({
            :auth_admin_prefix => auth_admin_prefix,
          })
        end
        it do
          should contain_neutron_api_config('filter:authtoken/auth_admin_prefix').with(
            :value => params[:auth_admin_prefix]
          )
        end
      end
    end
  end


  shared_examples_for 'a neutron server with some incorrect auth_admin_prefix set' do
    [ '/keystone/', 'keystone/', 'keystone' ].each do |auth_admin_prefix|
      describe "with keystone_auth_admin_prefix containing incorrect value #{auth_admin_prefix}" do
        before do
          params.merge!({
            :auth_admin_prefix => auth_admin_prefix,
          })
        end
        it do
          expect {
            should contain_neutron_api_config('filter:authtoken/auth_admin_prefix')
          }.to raise_error(Puppet::Error, /validate_re\(\): "#{auth_admin_prefix}" does not match/)
        end
      end
    end
  end

  shared_examples_for 'a neutron server with broken authentication' do
    before do
      params.delete(:auth_password)
    end
    it_raises 'a Puppet::Error', /auth_password must be set/
  end

  shared_examples_for 'a neutron server with log_file specified' do
    before do
      params.merge!(
        :log_file => '/var/log/neutron/server.log'
      )
    end
    it 'configures logging' do
      should contain_neutron_config('DEFAULT/log_file').with_value(params[:log_file])
      should contain_neutron_config('DEFAULT/log_dir').with_ensure('absent')
    end
  end

  context 'on Debian platforms' do
    let :facts do
      { :osfamily => 'Debian' }
    end

    let :platform_params do
      { :server_package => 'neutron-server',
        :server_service => 'neutron-server' }
    end

    it_configures 'a neutron server'
    it_configures 'a neutron server with broken authentication'
    it_configures 'a neutron server with log_file specified'
    it_configures 'a neutron server with auth_admin_prefix set'
    it_configures 'a neutron server with some incorrect auth_admin_prefix set'
  end

  context 'on RedHat platforms' do
    let :facts do
      { :osfamily => 'RedHat' }
    end

    let :platform_params do
      { :server_service => 'neutron-server' }
    end

    it_configures 'a neutron server'
    it_configures 'a neutron server with broken authentication'
    it_configures 'a neutron server with log_file specified'
    it_configures 'a neutron server with auth_admin_prefix set'
    it_configures 'a neutron server with some incorrect auth_admin_prefix set'
  end
end
