require 'rails/generators'

# Rails 3 Generator
class PostageappGenerator < Rails::Generators::Base
  class_option :api_key,
    aliases: [ '-k=value', '--api-key=value' ],
    type: :string,
    desc: 'Your PostageApp API key'
  
  def self.source_root
    @__source_root ||= File.expand_path(
      '../../../generators/postageapp/templates',
      __dir__
    )
  end
  
  def install
    unless (PostageApp::Env.rails_with_encrypted_credentials?)
      unless (options[:api_key])
        puts 'Must pass --api-key with API key of your PostageApp.com project'

        exit(-1)
      end
      
      template('initializer.rb', 'config/initializers/postageapp.rb')
    end

    copy_file('postageapp_tasks.rake', 'lib/tasks/postageapp_tasks.rake')

    puts run('rake postageapp:test')
  end
  
  def api_key
    options[:api_key]
  end
end
