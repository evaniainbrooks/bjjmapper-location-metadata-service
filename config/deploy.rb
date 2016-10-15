# config valid only for current version of Capistrano
lock '3.2.1'

set :application, 'rollfindr_locationfetchsvc'
set :repo_url, 'git@bitbucket.org:/rollfindr/locationfetchsvc.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/var/www/rollfindr_locationfetchsvc'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, fetch(:linked_files, []).push('config/database.yml')

# Default value for linked_dirs is []
# set :linked_dirs, fetch(:linked_dirs, []).push('bin', 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

set :unicorn_conf, "#{current_path}/config/unicorn.rb"
set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"

set :rack_env, :production
set :rvm_ruby_string, :local

namespace :app do
  task :update_rvm_key do
    on roles(:app) do
      execute :gpg, "--keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3"
    end
  end
end
before "rvm1:install:rvm", "app:update_rvm_key"

before 'deploy', 'rvm1:install:rvm'  # install/update RVM
before 'deploy', 'rvm1:install:ruby' # install Ruby and create gemset (both if missing)
before 'deploy', 'rvm1:install:gems'
after 'deploy:publishing', 'deploy:restart'
namespace :deploy do
  task :restart do
    on roles(:app) do
      within "#{fetch(:deploy_to)}/current" do
        execute :bundle, :exec, :unicorn, "-c #{fetch(:unicorn_conf)} -E #{fetch(:rack_env)} -D; fi"
      end
    end
  end
  task :start do
    on roles(:app) do
      within "#{fetch(:deploy_to)}/current" do
        execute :bundle, :exec, :unicorn, "-c #{fetch(:unicorn_conf)} -E #{fetch(:rack_env)} -D"
      end
    end
  end
  task :stop do
    on roles(:app) do
      execute "if [ -f #{fetch(:unicorn_pid)} ]; then kill -QUIT `cat #{fetch(:unicorn_pid)}`; fi"
    end
  end
end
