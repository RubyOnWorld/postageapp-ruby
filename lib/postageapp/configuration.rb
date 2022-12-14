# PostageApp::Configuration is used to retrieve and manipulate the options
# used to connect to the API. There are a number of options which can be set.
# The recommended method for doing this is via the initializer file that's
# generated upon installation: config/initializers/postageapp.rb

# Basic Options
# -------------
# :api_key - The API key used to send requests, can also be set via the
#            POSTAGEAPP_API_KEY environment variable. (required)
# :secure - true for HTTPS, false for HTTP connections (default: true)
# :recipient_override - Email address to send all email to regardless of
#                       specified recipients. Used for testing.

# Non-Rails Options
# -----------------
# :project_root - The base path of the project, used to determine where to
#                 save log files and failed API calls.
# :framework - A string identifier for the framework being used. Shows up in
#              the User-Agent identifier of requests.
# :environment - The operational mode of the application, typically either
#                'production' or 'development' but any string value is allowed.
#                (default: 'production')
# :logger - Used to assign a specific logger.

# Network Options
# ---------------
# :host - The API host to connect to (default: 'api.postageapp.com')
# :http_open_timeout - HTTP open timeout in seconds (default: 2)
# :http_read_timeout - Read timeout in seconds (default: 5)

# Proxy Options
# -------------
# :proxy_host - Proxy server hostname
# :proxy_port - Proxy server port
# :proxy_username - Proxy server username
# :proxy_password - Proxy server password

# Advanced Options
# ----------------
# :port - The port to make HTTP/HTTPS requests (default based on secure option)
# :scheme - Set to either `http` or `https` (default based on secure option)
# :requests_to_resend - List of API calls that should be replayed if they fail.
#                       (default: send_message)

class PostageApp::Configuration
  # == Constants ============================================================

  SOCKS5_PORT_DEFAULT = 1080
  HTTP_PORT_DEFAULT = 80
  HTTPS_PORT_DEFAULT = 443

  SCHEME_FOR_SECURE = {
    true => 'https'.freeze,
    false => 'http'.freeze
  }.freeze

  CONFIG_PARAMS = {
    api_key: {
      default: nil,
      desc: 'Project API key to use',
      required: 'for project API functions'
    },
    account_api_key: {
      default: nil,
      desc: 'Account API key to use',
      required: 'for account API functions'
    },
    postback_secret: {
      default: nil,
      desc: 'Secret to use for validating ActionMailbox requests'
    },
    project_root: {
      default: -> {
        if (defined?(Rails) and Rails.respond_to?(:root))
          Rails.root
        else
          Dir.pwd
        end
      },
      desc: 'Project root for logging purposes'
    },
    recipient_override: {
      default: nil,
      interrogator: true,
      desc: 'Override sender on `send_message` calls'
    },
    logger: {
      default: nil,
      env: false,
      desc: 'Logger instance to use'
    },
    secure: {
      default: true,
      interrogator: true,
      env: false,
      after_set: -> (config) {
        if (config.secure?)
          config.protocol = 'https'
          if (config.port == 80)
            config.port = 443
          end
        else
          config.protocol = 'http'
          if (config.port == 443)
            config.port = 80
          end
        end
      },
      desc: 'Enable verifying TLS connections'
    },
    verify_tls: {
      default: true,
      aliases: [ :verify_certificate ],
      interrogator: true,
      parse: -> (v) {
        case (v)
        when 'true', 'yes', 'on'
          true
        when String
          v.to_i != 0
        else
          !!v
        end
      },
      desc: 'Enable TLS certificate verification'
    },
    host: {
      default: 'api.postageapp.com'.freeze,
      desc: 'API host to contact'
    },
    port: {
      default: 443,
      desc: 'API port to contact'
    },
    scheme: {
      default: 'https'.freeze,
      aliases: [ :protocol ],
      desc: 'HTTP scheme to use'
    },
    proxy_username: {
      default: nil,
      aliases: [ :proxy_user ],
      desc: 'SOCKS5 proxy username'
    },
    proxy_password: {
      default: nil,
      aliases: [ :proxy_pass ],
      desc: 'SOCKS5 proxy password'
    },
    proxy_host: {
      default: nil,
      desc: 'SOCKS5 proxy host'
    },
    proxy_port: {
      default: 1080,
      parse: -> (v) { v.to_i },
      desc: 'SOCKS5 proxy port'
    },
    open_timeout: {
      default: 5,
      aliases: [ :http_open_timeout ],
      parse: -> (v) { v.to_i },
      desc: 'Timeout in seconds when initiating requests'
    },
    read_timeout: {
      default: 10,
      aliases: [ :http_read_timeout ],
      parse: -> (v) { v.to_i },
      desc: 'Timeout in seconds when awaiting responses'
    },
    retry_methods: {
      default: %w[ send_message ].freeze,
      aliases: [ :requests_to_resend ],
      parse: -> (v) {
        case (v)
        when String
          v.split(/\s*(?:,|\s)\s*/).grep(/\S/)
        else
          v
        end
      },
      desc: 'Which API calls to retry, comma and/or space separated'
    },
    framework: {
      default: -> {
        if (defined?(Rails) and Rails.respond_to?(:version))
          'Ruby %s / Ruby on Rails %s' % [
            RUBY_VERSION,
            Rails.version
          ]
        else
          'Ruby %s' % RUBY_VERSION
        end
      },
      desc: 'Framework used'
    },
    environment: {
      default: 'production',
      desc: 'Environment to use'
    }
  }.freeze

  # == Properties ===========================================================

  CONFIG_PARAMS.each do |param, config|
    attr_reader param

    ivar = config[:ivar] ||= :"@#{param}"
    mutator_method = :"#{param}="
    config[:sources] = [ param ]
    after_set = config[:after_set]

    if (parser = config[:parse])
      define_method(mutator_method) do |v|
        instance_variable_set(ivar, parser.call(v))
      end
    else
      define_method(mutator_method) do |v|
        instance_variable_set(ivar, v)

        after_set and after_set[self]
      end
    end

    interrogator_method = nil

    if (config[:interrogator])
      interrogator_method = :"#{param}?"
      define_method(interrogator_method) do
        !!instance_variable_get(ivar)
      end
    end

    if (param_aliases = config[:aliases])
      param_aliases.each do |param_alias|
        config[:sources] << param_alias

        alias_method param_alias, param
        alias_method :"#{param_alias}=", mutator_method

        if (config[:interrogator])
          alias_method :"#{param_alias}?", interrogator_method
        end
      end
    end

    unless (config[:env] === false)
      config[:env_vars] = config[:sources].map do |source|
        'POSTAGEAPP_' + source.to_s.upcase
      end
    end

    # config[:getters] = config[:sources].map do |source|
    #   -> (credentials) { credentials[:source] }
    # end + config[:env_vars].map do |var|
    #   -> (_) { ENV[var] }
    # end
  end

  # == Class Methods ========================================================

  def self.params
    CONFIG_PARAMS
  end

  # == Instance Methods =====================================================

  def initialize
    credentials = self.rails_credentials

    CONFIG_PARAMS.each do |param, config|
      value = (
        config[:sources]&.map { |s| credentials[s] }&.compact&.first ||
        config[:env_vars]&.map { |v| ENV[v] }&.compact&.first
      )

      if (value)
        if (config[:parse])
          instance_variable_set(config[:ivar], config[:parse].call(value))
        else
          instance_variable_set(config[:ivar], value)
        end
      else
        case (config[:default])
        when Proc
          instance_variable_set(config[:ivar], config[:default].call)
        else
          instance_variable_set(config[:ivar], config[:default])
        end
      end
    end
  end

  # Returns true if the port used for the API is the default port, otherwise
  # false. 80 for HTTP, 443 for HTTPS.
  def port_default?
    self.port == (self.secure? ? HTTPS_PORT_DEFAULT : HTTP_PORT_DEFAULT)
  end

  # Returns true if a proxy is defined, otherwise false.
  def proxy?
    self.proxy_host and self.proxy_host.match(/\A\S+\z/)
  end

  # Returns the endpoint URL to make API calls
  def url
    '%s://%s%s' % [
      self.scheme,
      self.host,
      self.port_default? ? '' : (':%d' % self.port)
    ]
  end

  # Returns a connection aimed at the API endpoint
  def http
    PostageApp::HTTP.connect(self)
  end

protected
  def rails_credentials
    if (PostageApp::Env.rails_with_encrypted_credentials?)
      Rails.application.credentials.postageapp
    end or { }
  end
end
