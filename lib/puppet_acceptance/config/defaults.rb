module PuppetAcceptance
  module Config
    DEFAULTS = PuppetAcceptance::Config::Value.new({
      :config         => nil,
      :options_file   => ['options.rb', File.join('acceptance', 'options.rb')],
      :type           => 'pe',
      :helper         => [],
      :load_path      => [],
      :tests          => [],
      :pre_suite      => [],
      :post_suite     => [],
      :provision      => true,
      :preserve_hosts => false,
      :root_keys      => false,
      :install        => [],
      :modules        => [],
      :quiet          => false,
      :xml            => false,
      :color          => true,
      :debug          => false,
      :dry_run        => false,
      :fail_mode      => nil,
      :timesync       => false,
      :repo_proxy     => false,
      :add_el_extras  => false,
      :pe_location    => nil,
      :pe_build       => nil,
      :pe_build_file  => nil,
      :is_pe          => true,
      :print_help     => false,
      :ssh            => {
        :config                => false,
        :paranoid              => false,
        :timeout               => 300,
        :auth_methods          => ["publickey"],
        :keys                  => [ File.expand_path( "#{ENV['HOME']}/.ssh/id_rsa" ) ],
        :port                  => 22,
        :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
        :forward_agent         => true
      }
    })

    NEW_DEFAULTS = PuppetAcceptance::Config::Value.new({
      :host => {
        :default => {
          :roles => []
        }
      },
      :provisioner => {},
      :connection => {
        :ssh => {
          :config                => false,
          :paranoid              => false,
          :timeout               => 300,
          :auth_methods          => ["publickey"],
          :keys                  => [ File.expand_path( "#{ENV['HOME']}/.ssh/id_rsa" ) ],
          :port                  => 22,
          :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
          :forward_agent         => true
        }
      },
      :check => [ ],
      :software => {},
      :runner => {
        :options_file   => ['options.rb', File.join('acceptance', 'options.rb')],
        :type           => 'pe',
        :provision      => true,
        :preserve_hosts => false,
        :print_help     => false

      },
      :output => {
        :console => {
          :endpoint => STDOUT,
          :level => :info,
          :format => :conosle,
          :color => true
        }
      }
    })
  end
end
