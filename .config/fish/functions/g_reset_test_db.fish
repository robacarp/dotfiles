function g_reset_test_db
  bundle exec rake db:structure:dump
  env RAILS_ENV=test bundle exec rake db:drop db:create db:structure:load
end
