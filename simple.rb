# -----------------------------------------------------------------------
# Rails template with: 
#   RSpec
#   Cucumber (and Webrat)
#   Factory Girl
#   JQuery
# -----------------------------------------------------------------------
# Remove default cruft.
run 'rm README'
run 'rm public/index.html'
run 'rm public/favicon.ico'
run 'rm public/images/rails.png'

# Copy database.yml
run 'cp config/database.yml config/database.yml.example'

gem "rspec", :lib => "spec", :version => "1.2.9"
gem "rspec-rails", :lib => "spec/rails", :version => "1.2.9"
gem "cucumber", :version => "0.6.1", :lib => false
gem "cucumber-rails", :version => "0.2.3", :lib => false
gem "webrat", :version => "0.6.0"
gem "thoughtbot-factory_girl", :lib => "factory_girl"
rake "gems:unpack"

# Plugins
plugin 'exception_notifier', :git => 'git://github.com/rails/exception_notification.git'

# Download jquery
run "curl -L http://jqueryjs.googlecode.com/files/jquery-1.3.2.min.js > public/javascripts/jquery.js"

# Generators
generate :rspec
generate :cucumber

capify!

file 'Capfile', <<-FILE
  load 'deploy' if respond_to?(:namespace) # cap2 differentiator
  Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
  load 'config/deploy'
FILE

# .gitignore 
file '.gitignore', <<-FILE
.DS_Store
*.sw[po]
log/*.log
tmp/**/*
config/database.yml
db/*.sqlite3
db/schema.rb
FILE

 
# Use Active Record session store
initializer 'session_store.rb', <<-FILE
  ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
  ActionController::Base.session_store = :active_record_store
FILE

# Features

# paths.rb
file("features/support/paths.rb") do
%q{
module NavigationHelpers
  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in webrat_steps.rb
  #
  def path_to(page_name)
    case page_name
    
		when /the home\s?page/
      '/'
   
    # Add more mappings here.
    # Here is a more fancy example:
    #
    #   when /^(.*)'s profile page$/i
    #     user_profile_path(User.find_by_login($1))

    else
      raise "Can't find mapping from \"#{page_name}\" to a path.\n" +
        "Now, go and add a mapping in #{__FILE__}"
    end
  end
end

World(NavigationHelpers)
}
end

rake "db:create"
rake "db:sessions:create"
rake "db:migrate"

# Remove test directory
run 'rm -rf test'

# Set up git
git :init
git :add => '.'

# Done
