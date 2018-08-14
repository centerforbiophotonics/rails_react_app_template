
def run_requirement_check
  yarn_version = run("yarn --version")
  if yarn_version.nil?
    fail Rails::Generators::Error, "Yarn not detected. Make sure yarn is installed."
  end
end

def add_gems
  gem "webpacker"
  gem "webpacker-react"
  gem 'rubycas-client-rails', :git => 'https://github.com/centerforbiophotonics/rubycas-client-rails.git'
  gem 'pundit'

end

def install_webpacker
  run("bundle exec rails webpacker:install")
  run("bundle exec rails webpacker:install:react")

  run("rm app/javascript/packs/hello_react.jsx")
  run("rm app/javascript/packs/application.js")


  create_global_react_app_css

  file 'app/javascript/packs/application.js', <<-CODE
import WebpackerReact from 'webpacker-react';
import 'bootstrap/dist/css/bootstrap.css';
import 'components/application.css'

  CODE


  insert_into_file 'app/views/layouts/application.html.erb', 
    "
    <%= javascript_pack_tag 'application' %>
    <%= stylesheet_pack_tag 'application' %>
",
    after: "<%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload' %>\n" 

end

def add_yarn_packages
  run("yarn add webpacker-react bootstrap react-table react-select react-autosuggest prop-types \"@fortawesome/fontawesome-svg-core\" \"@fortawesome/free-solid-svg-icons\" \"@fortawesome/react-fontawesome\"")
end

def create_generator
  run "cp -vr #{__dir__}/generators lib/generators"
end

def generate_user_mvc
  default_user_attrs = "name:string email:string cas_user:string roles:string"
  additional_user_model_attrs = ask("In addition to #{default_user_attrs}, what attributes/columns should be included in the User model? (press enter for none)")
  generate "model User #{default_user_attrs} #{additional_user_model_attrs}"
  run "rails generate react_view User #{default_user_attrs} #{additional_user_model_attrs}"
end

def run_user_migration
  run "rake db:migrate"
end

def create_dev_user
  run "rails runner \"User.create(:name => 'dev_user', :cas_user => 'dev_user')\""
end

def install_pundit
  generate "pundit:install"
end

def configure_cas_for_ucd_ssodev
  insert_into_file 'config/application.rb', 
    "
    config.rubycas.cas_base_url = \"https://ssodev.ucdavis.edu/cas/\"
    config.rubycas.cas_service_url = \"https://localhost:3000/\"
",
    after: "config.load_defaults 5.2\n" 
end

def add_filters_and_helpers_for_cas
    insert_into_file 'app/controllers/application_controller.rb', "
  before_action RubyCAS::Filter, :if => -> { Rails.env.production? }
  before_action :dev_cas_user, :if => -> { Rails.env.development? }
  helper_method :current_user

  def dev_cas_user
    session[:cas_user] = \"dev_user\"
  end

  def current_user
    User.find_by(:cas_user => session[:cas_user])
  end
",
    after: "class ApplicationController < ActionController::Base\n" 
end

def create_global_react_app_css
  template_file = "#{__dir__}/application.css"
  template template_file, File.join("app/javascript/components/application.css")
  
end

run "spring stop"
run_requirement_check
add_gems

after_bundle do 
  configure_cas_for_ucd_ssodev
  install_pundit
  install_webpacker
  add_yarn_packages
  create_generator
  generate_user_mvc
  run_user_migration
  create_dev_user
  add_filters_and_helpers_for_cas

  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit.'"
end