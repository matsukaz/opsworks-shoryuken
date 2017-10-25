node[:deploy].each do |application, deploy|
  if deploy['shoryuken']
    shoryuken_config = deploy['shoryuken']
    release_path = ::File.join(deploy[:deploy_to], 'current')
    rails_env = deploy[:rails_env]
    start_command = shoryuken_config['start_command'] || 'bundle exec shoryuken -R -L log/shoryuken.log -C config/shoryuken.yml'
    env = deploy['environment_variables'] || {}

    template "#{deploy[:deploy_to]}/shared/config/shoryuken.yml" do
      source "shoryuken.yml.erb"
      mode "0660"
      group deploy[:group]
      owner deploy[:user]
      variables :content => YAML.dump(JSON.parse(shoryuken_config[:config].to_json))
      only_if do
        shoryuken_config['config'].present?
      end
    end

    execute "symlink shoryuken.yml" do
      command "ln -s #{deploy[:deploy_to]}/shared/config/shoryuken.yml #{deploy[:deploy_to]}/current/config/shoryuken.yml"
      action :run
      only_if do
        shoryuken_config['config'].present?
      end
    end

    template 'setup shoryuken.conf' do
      path "/etc/init/shoryuken-#{application}.conf"
      source 'shoryuken.conf.erb'
      owner 'root'
      group 'root'
      mode 0644
      variables({
        app_name: application,
        user: deploy[:user],
        group: deploy[:group],
        release_path: release_path,
        rails_env: rails_env,
        start_command: start_command,
        env: env,
      })
    end

    service "shoryuken-#{application}" do
      provider Chef::Provider::Service::Upstart
      supports stop: true, start: true, restart: true, status: true
    end

    # always restart shoryuken on deploy since we assume the code must need to be reloaded
    bash 'restart_shoryuken' do
      code 'echo noop'
      notifies :restart, "service[shoryuken-#{application}]"
    end
  end
end
