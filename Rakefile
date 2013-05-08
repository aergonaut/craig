require './craig_worker'

namespace :craig do
  desc "put a job on the queue"
  task :run do
    CraigWorker.perform_async
  end
end

namespace :db do
  desc "run database migrations"
  task :migrate do
    migrations_dir = "./db/migrations"
    DB = Sequel.connect ENV["DATABASE_URL"]
    Sequel.extension :migration
    unless Sequel::Migrator.is_current? DB, migrations_dir
      Sequel::Migrator.apply DB, migrations_dir
    end
  end
end
