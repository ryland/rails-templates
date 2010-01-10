# -----------------------------------------------------------------------
# Rails template with: 
#   RSpec
#   Cucumber (and Webrat)
#   Factory Girl
#   Authlogic (and basic session/user support)
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
gem "authlogic", :git => "git://github.com/binarylogic/authlogic.git"
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


# Setup AuthLogic
# session model and controller
generate(:session, "user_session") 
generate(:controller, "user_sessions")

# map user_sesion resources
route "map.resource :account, :controller => 'users'"
route "map.resource :user_session"
route "map.login  '/login',  :controller => 'user_sessions', :action => 'new'"
route "map.logout  '/logout',  :controller => 'user_sessions', :action => 'destroy'"
route "map.root :controller => 'user_sessions', :action => 'new'"

# -----------------------------------------------------------------------
# Authlogic
# -----------------------------------------------------------------------
# User Migration
generate "rspec_model", "user", "login:string", "email:string", "crypted_password:string", "password_salt:string", "persistence_token:string", "single_access_token:string", "perishable_token:string", "last_login_at:datetime", "last_login_ip:string"

# User Spec
file "spec/models/user_spec.rb", <<-FILE

require 'spec_helper'
describe User do
  it "should create a new instance given valid attributes" do
    User.create!(Factory.attributes_for(:user))
  end
end
FILE

# UsesSessionsController
file "app/controllers/user_sessions_controller.rb", <<-FILE
class UserSessionsController < ApplicationController  
  before_filter :anonymous_required, :only => [:new, :create]
  before_filter :login_required, :only => :destroy

  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end
end
FILE

# User, acts_as_authentic style
file "app/models/user.rb", <<-FILE
class User < ActiveRecord::Base
  acts_as_authentic
  attr_accessible :login, :email, :password, :password_confirmation
  
end
FILE

file "app/controllers/users_controller.rb", <<-FILE
class UsersController < ApplicationController
  before_filter :anonymous_required, :only => [:new, :create]
  before_filter :login_required, :only => [:show, :edit, :update]

  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
    if @user.save
      flash[:notice] = "Account registered!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end

  def show
    @user = @current_user
  end

  def edit
    @user = @current_user
  end

  def update
    @user = @current_user # makes our views "cleaner" and more consistent
    if @user.update_attributes(params[:user])
      flash[:notice] = "Account updated!"
      redirect_to account_url
    else
      render :action => :edit
    end
  end
end
FILE

file "app/controllers/application_controller.rb", <<-FILE
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.user
    end
    
    def login_required
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to new_user_session_url
        return false
      end
    end

    def anonymous_required
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to account_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
end
FILE

file "app/views/users/_form.erb", <<-FILE
<p>
  <%= form.label :login %><br />
  <%= form.text_field :login %>
</p>

<p>
  <%= form.label :email %><br />
  <%= form.text_field :email %>
</p>

<p>
  <%= form.label :password, form.object.new_record? ? nil : "Change password" %><br />
  <%= form.password_field :password %>
</p>

<p>
  <%= form.label :password_confirmation %><br />
  <%= form.password_field :password_confirmation %>
</p>
FILE

file "app/views/users/edit.html.erb", <<-FILE
<h1>Edit Account</h1>
 
<% form_for @user, :url => account_path do |f| %>
  <%= f.error_messages %>
  <%= render :partial => 'form', :object => f %>
  <%= f.submit "Update" %>
<% end %>
 
<br /><%= link_to "My Profile", account_path %>
FILE

file "app/views/users/new.html.erb", <<-FILE
<h1>Register</h1>
 
<% form_for @user, :url => account_path do |f| %>
  <%= f.error_messages %>
  <%= render :partial => 'form', :object => f %>
  <%= f.submit "Register" %>
<% end %>
FILE

file "app/views/users/show.html.erb", <<-FILE
<p>
  <b>Login:</b>
  <%=h @user.login %>
</p>
<p>
  <b>Email:</b>
  <%=h @user.email %>
</p>
 
<%= link_to 'Edit', edit_account_path %>
FILE

file "app/views/user_sessions/new.html.erb", <<-FILE
<h1>Login</h1>
 
<% form_for @user_session, :url => user_session_path do |f| %>
  <%= f.error_messages %>
  <p>
    <%= f.label :login %><br />
    <%= f.text_field :login %>
  </p>

  <p>
  <%= f.label :password %><br />
  <%= f.password_field :password %>
  </p>

  <%= f.check_box :remember_me %><%= f.label :remember_me %><br />
  <br />
  <%= f.submit "Submit" %>
<% end %>
FILE

file "app/views/layouts/application.html.erb", <<-FILE
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
  <title><%= controller.controller_name %>: <%= controller.action_name %></title>
  <%= stylesheet_link_tag 'scaffold' %>
  <%= javascript_include_tag 'jquery' %>
</head>
<body>

<div id="header">
  <% if current_user -%>
    <%= link_to "Log Out", logout_path, :method => :delete %>
  <% else %>
    <%= link_to "Log In", login_path %>
  <% end -%>
</div>

<div id="flash">
  <% if flash[:notice] -%>
    <div class="notice"><%= flash[:notice] %></div>
  <% end -%>
  <% if flash[:error] -%>
    <div class="error"><%= flash[:error] %></div>
  <% end -%>
</div>

<%= yield %>

</body>
</html>
FILE

 
# Use Active Record session store
initializer 'session_store.rb', <<-FILE
  ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
  ActionController::Base.session_store = :active_record_store
FILE

# Features

# User login
file("features/user_login.feature") do
  <<-EOF
Feature: User login
  In order to access the site
  the user
  wants to login with login and password

  Background:
    Given a user with the login "duder" exists

  Scenario: User login
    Given I go to the login page
    And I follow "Log In"
    And I fill in "Login" with "duder"
    And I fill in "Password" with "secret"
    When I press "Submit"
    Then I should be on the account page
    And I should see "Login successful!"
    And I should see "Login"
    And I should see "Email"
    When I follow "Edit"
    Then I should see "Edit Account"
  EOF
end

file("features/user_signup.feature") do
  <<-EOF
  Feature: User signup
  In order to login
  User wants to signup and have an account

  Scenario: Register new signup
    Given I am on the sign up page
    And I fill in the following:
      | Login            | newbie |
      | Email            | newbie@example.com |
      | Password         | secret        |
      | Password confirmation | secret |
    When I press "Register"
    Then I should see "Account registered!"

  Scenario: Check for too short email address during signup
    Given I am on the sign up page
    And I fill in "Login" with "newbie"
    And I press "Register"
    Then I should see "Email is too short (minimum is 6 characters)"

  Scenario: Checking the password confirmation
    Given I am on the sign up page
    And I fill in "Login" with "newbie2"
    And I fill in "Email" with "newbie2@example.com"
    And I fill in "Password" with "foobar"
    And I fill in "Password Confirmation" with "barfoo"
    When I press "Register"
    Then I should see "Password doesn't match confirmation"

  Scenario: Check for invalid email address during signup
    Given I am on the sign up page
    And I fill in "Login" with "newbie3"
    And I fill in "Email" with "xxxxxx.com"
    When I press "Register"
    Then I should see "Email should look like an email address"
  EOF
end

file("features/step_definitions/login_steps.rb") do
  <<-EOF
Given /^a user with the login "([^\"]*)" exists$/ do |login|
  user = User.create do |u|
    u.password = u.password_confirmation = "secret"
    u.login = login
    u.email = "lamonte@example.com"
  end
  user.save
end
  EOF
end

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
    when /the account page/
      '/account'
    when /the login page/
      '/login'
    when /the sign up page/
      '/account/new'
    
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

# Factory Girl
file("spec/factories.rb") do
%q{
Factory.define :user do |u|
  u.login "terry"
  u.password "secret"
  u.password_confirmation "secret"
  u.email {|e| "#{e.login.downcase}@example.com" }
end
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

# Tada
