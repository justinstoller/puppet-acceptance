require 'open-uri'
#
# Example configuration options...
#
# config:
# options_file:
# type:
#
# helper:
# load_path:
#
# pre_suite:
# tests:
# post_suite:
#
# provision:
# preserve_hosts:
#
# dry_run:
# fail_mode:
# install:
# modules:
#
# quiet:
# xml:
# color:
# debug:
#
# ntp:
# root_keys:
# repo_proxy:
# add_el_extras:
#
# print_help:
#
# # also setable from a host config file specified by the :config option above
# network:
#   nfs_server:  none
#   consoleport: 443
#   ssh:
#     timeout:      300
#     auth_methods: publickey
#     keys:         /Users/justin/.ssh/id_rsa
#   hosts:
#     - name: rhel-6-latest-64-1
#       roles:
#         - master
#         - database
#         - agent
#       platform: el-6-x86_64
#       template: myTemplate
#       snapshot: demo1-ready
#       provisioner: vsphere
#       ip: 192.168.0.10
#
#
# # also setable from a host config file or a .fog file
# provisioners:
#   - name: vcloud
#     datastore:    instance0
#     folder:       Delivery/Quality Assurance/Enterprise/Dynamic
#     resourcepool: delivery/Quality Assurance/Enterprise/Dynamic
#     password:     mYP@$$w0rd
#
module PuppetAcceptance
  class Configuration
    attr_accessor :defaults

    def initialize( defaults = Hash.new, &block )
      @defaults = defaults
      yield self if block_given?
    end

    def []( key )
      retrieve( key )
    end

    def to_ary
      defaults.to_a
    end
    alias_method :to_a, :to_ary

    def retrieve( key )
      if defaults.has_key?( key.to_s )
        raw_value = defaults.fetch( key.to_s )
      else
        raw_value = defaults.fetch( key.to_sym, self.class.new )
      end

      if raw_value.is_a? Hash
        value = self.class.new( raw_value )
      else
        value = raw_value
      end

      set( key, value ) unless exists?( key )

      return value
    end

    def exists?( key )
      defaults.has_key?( key.to_s ) or defaults.has_key?( key.to_sym )
    end

    def []=( key, value )
      set( key, value )
    end

    def set( key, value )
      defaults[key.to_sym] = value
    end

    def to_hash
      @defaults
    end

    def finalize!
      final = {}
      defaults.each_pair do |key, value|
        if value.is_a? self.class
          final[key] = value.finalize!
        else
          final[key] = value
        end
      end

      return final
    end

    def method_missing( meth, *values, &block )
      key = meth.to_s.end_with?( '=' ) ? meth.to_s.chop.to_sym : meth
      if values.empty? and not block_given?
        return self[key]

      elsif values.empty? and block_given?
        if block.arity == 1
          block.call( retrieve( key ) )

        else
          set( key, block )
        end

      elsif values.length == 1
        set( key, values.first )

      else
        set( key, values )
      end
    end

    def merge( other_conf )
      if other_conf.is_a? self.class
        values = other_conf.defaults
      elsif other_conf.is_a? Hash
        values = other_conf
      else
        raise "Don't know how to merge #{other_conf.class}: #{other_conf.inspect}"
      end
      self.class.new( defaults.merge( values ) )
    end
  end

  class Options
    GITREPO = 'git://github.com/puppetlabs'

    DEFAULTS = Configuration.new({
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

#############################################################################
# BEGIN OLD TEST CONFIG CODE
#############################################################################

    # Needs to return an objet that looks like an old @config hash
    def parse_config_files( options )
      @is_pe = options[:type] =~ /pe/ ? true : false
      unless ENV['IS_PE'].nil?
        @is_pe ||= ENV['IS_PE'] == 'true'
      end

      load_file( options[:config] )
    end

    def load_file( config_info )
      if config_info.is_a?( Hash ) or config_info.is_a?( Configuration )
        config = config_info
      else
        config = YAML.load_file( config_info )

        # Make sure the roles array is present for all hosts
        config['HOSTS'].each_key do |host|
          config['HOSTS'][host]['roles'] ||= []
        end
      end

      # Merge some useful date into the config hash
      config['CONFIG'] ||= {}
      consoleport = ENV['consoleport'] || config['CONFIG']['consoleport'] || 443
      config['CONFIG']['consoleport']        = consoleport.to_i
      config['CONFIG']['ssh']                = DEFAULTS[:ssh].merge(config['CONFIG']['ssh'] || {})

      if is_pe?
        config['CONFIG']['pe_dir']           = puppet_enterprise_dir
        config['CONFIG']['pe_ver']           = puppet_enterprise_version
        config['CONFIG']['pe_ver_win']       = puppet_enterprise_version_win
      end

      Configuration.new( config )
    end

    def is_pe?
      @is_pe
    end

    def puppet_enterprise_dir
      @pe_dir ||= ENV['pe_dist_dir'] || '/opt/enterprise/dists'
    end

    def load_pe_version
      dist_dir = puppet_enterprise_dir
      version_file = ENV['pe_version_file'] || 'LATEST'
      version = ""
      begin
        open("#{dist_dir}/#{version_file}") do |file|
          while line = file.gets
            if /(\w.*)/ =~ line then
              version = $1.strip
            end
          end
        end
      rescue
        version = 'unknown'
      end
      return version
    end

    def puppet_enterprise_version
      @pe_ver ||= load_pe_version if is_pe?
    end

    def load_pe_version_win
      dist_dir = puppet_enterprise_dir
      version_file = ENV['pe_version_file'] || 'LATEST-win'
      version = ""
      begin
        open("#{dist_dir}/#{version_file}") do |file|
          while line = file.gets
            if /(\w.*)/ =~ line then
              version=$1.strip
            end
          end
        end
      rescue
        version = 'unknown'
      end
      return version
    end

    def puppet_enterprise_version_win
      @pe_ver_win ||= load_pe_version_win if is_pe?
    end

    # This isn't the config's responsibility and should be merged
    # with the formatting done with `pretty_print` below....
    #
    def dump; end # Substiting a no-op for now
    #def dump
    #  # Access "platform" for each host
    #  @config["HOSTS"].each_key do|host|
    #    @logger.notify "Platform for #{host} #{@config["HOSTS"][host]['platform']}"
    #  end

    #  # Access "roles" for each host
    #  @config["HOSTS"].each_key do|host|
    #    @config["HOSTS"][host]['roles'].each do |role|
    #      @logger.notify "Role for #{host} #{role}"
    #    end
    #  end

    #  # Print out Ruby versions
    #  @config["HOSTS"].each_key do|host|
    #      @logger.notify "Ruby version for #{host} #{@config["HOSTS"][host][:ruby_ver]}"
    #  end

    #  # Access @config keys/values
    #  @config["CONFIG"].each_key do|cfg|
    #      @logger.notify "Config Key|Val: #{cfg} #{@config["CONFIG"][cfg].inspect}"
    #  end
    #end

#############################################################################
# END OLD TEST CONFIG CODE
#############################################################################

    def parse_args( arguments )
      cli_args_parser = register_cli_options
      parsed_cli_args = parse_cli_args( cli_args_parser, arguments )

      if parsed_cli_args.exists?( :options_file )
        locations = Array( parsed_cli_args[:options_file] )
      else
        locations = DEFAULTS[:options_file]
      end

      args_location    = locations.find {|loc| File.exists?( File.expand_path( loc )) }
      parsed_file_args = parse_file_args( args_location )

      munged_cli_args  = munge_args( parsed_cli_args  )
      munged_file_args = munge_args( parsed_file_args )

      merged_args = merge_args( DEFAULTS, munged_file_args, munged_cli_args )

      if merged_args[:print_help] or ( arguments.empty? && parsed_file_args.empty? )
        puts cli_args_parser
        exit # We should have a real way to say we want to terminate the program....
      end

      validate_args( merged_args )

      return merged_args.finalize!
    end

    def parse_cli_args( parser, args )
      args_hash = {}

      set_args_hash( args_hash )
      parser.parse( args )
      unset_args_hash

      return Configuration.new( args_hash )
    end

    def parse_file_args( options_file_path )
      return Configuration.new unless options_file_path

      options_file_path = File.expand_path( options_file_path )
      # this eval will allow the specified options file to have access to our
      # scope.  it is important that the variable 'options_file_path' is
      # accessible, because some existing options files (e.g. puppetdb) rely on
      # that variable to determine their own location (for use in 'require's, etc.)
      result = eval( File.read( options_file_path ) )

      if result.is_a? Hash
        return Configuration.new( result )
      elsif result.is_a? Configuration
        return result
      end
    end

    def munge_args( opts )
      munged_opts = opts.dup

      opts_that_take_lists = [ :helper, :load_path, :tests, :pre_suite,
                               :post_suite, :install, :modules          ]

      opts_that_take_lists.each do |key|
        munged_opts[key] = munge_possible_arg_list( opts[key] ) if opts.exists?( key )
      end

      if munged_opts.exists?( :install )
        munged_opts[:install] = parse_install_options( munged_opts[:install] )
      end

      opts_that_take_file_lists = [ :pre_suite, :post_suite, :tests, :helper ]
      opts_that_take_file_lists.each do |key|
        if munged_opts.exists?( key )

          munged_opts[key] = file_list( munged_opts[key] )

          munged_opts[key] = munged_opts[key].map do |file|
            File.expand_path( file )
          end
        end
      end

      single_files_to_be_expanded = [ :options_file ]
      single_files_to_be_expanded.each do |key|
        munged_opts[key] = File.expand_path( munged_opts[key] ) if munged_opts.exists?( key )
      end

      # what to do with you???
      munged_opts[:keyfile] = File.expand_path( opts[:keyfile] ) if opts.exists?( :keyfile )

      return munged_opts
    end

    def merge_args( defaults, args_from_file, args_from_cli )
      user_supplied_args = args_from_file.merge( args_from_cli )
      options = defaults.merge( user_supplied_args )

      return options
    end

    def pretty_print_args( args )
      pretty = [ "Options" ] +
        pretty_print_hash( args, "\t" )

      return pretty.compact.join( "\n" )
    end

    def pretty_print_hash( args, offset )
      args.map do |arg, val|
        if val and val != []
          [ "#{offset}#{arg.to_s}:" ] +
          if val.kind_of?( Array )
            val.map do |v|
              [ "#{offset}\t#{v.to_s}" ]
            end
          elsif val.kind_of?( Hash )
            pretty_print_hash( val, offset + offset )
          else
            [ "#{offset}\t#{val.to_s}" ]
          end
        end
      end.flatten
    end


    # We raise here instead of call `raise_and_report` because we don't have a logger here
    # and we expect to be called without one
    def validate_args( args )
      if args[:type] && args[:type] !~ /(pe)|(git)/
        raise ArgumentError.new(
          "--type must be one of pe or git, not '#{args[:type]}'" )
      end

      unless ["fast", "stop", nil].include?( args[:fail_mode] )
        raise ArgumentError.new( "--fail-mode must be one of fast, stop" )
      end

      unless args[:config]
        raise ArgumentError.new(
          "We require a Host Configuration file\n" +
          "Please specify one with `-c`, `--config` on the command line\n" +
          "or with the :config attribute in an options file" )
      end

      unless args[:options_file]
        unless File.exists?( File.expand_path( args[:options] ) )
          raise ArgumentError.new(
            "Specified options file '#{args[:options_file]}' does not exist!" )
        end
      end
    end

    def munge_possible_arg_list( possibly_a_list )
      case possibly_a_list
      when Array
        return possibly_a_list
      when String
        return possibly_a_list.split( ',' )
      else
        return Array( possibly_a_list )
      end
    end

    def parse_install_options(install_opts)
      install_opts.map! { |opt|
        case opt
          when /^puppet\//
            opt = "#{GITREPO}/puppet.git##{opt.split('/', 2)[1]}"
          when /^facter\//
            opt = "#{GITREPO}/facter.git##{opt.split('/', 2)[1]}"
          when /^hiera\//
            opt = "#{GITREPO}/hiera.git##{opt.split('/', 2)[1]}"
          when /^hiera-puppet\//
            opt = "#{GITREPO}/hiera-puppet.git##{opt.split('/', 2)[1]}"
        end
        opt
      }
      install_opts
    end

    def file_list(paths)
      files = []
      if not paths.empty?
        paths.each do |root|
          if File.file? root then
            files << root
          else
            discover_files = Dir.glob(
              File.join(root, "**/*.rb")
            ).select { |f| File.file?(f) }
            if discover_files.empty?
              raise ArgumentError, "Empty directory used as an option (#{root})!"
            end
            files += discover_files
          end
        end
      end
      files
    end

    def set_args_hash( a_hash )
      @current_arg_hash = a_hash
    end

    def unset_args_hash
      @current_arg_hash = nil
    end

    def register_arg( *things )
      value = things.pop
      length = things.length
      current_hsh = @current_arg_hash
      things.each_with_index do |key, i|
        if i == ( length - 1 )
          current_hsh[key] = value
        else
          current_hsh = current_hsh[key]
        end
      end
    end

    def register_cli_options
      optparse = OptionParser.new do |opts|
        # set a banner
        opts.banner = "Usage: #{File.basename($0)} [options...]"

        opts.on '-c', '--config file',
                'use configuration file' do |file|
          register_arg( :config, file )
        end

        opts.on '-o', '--options-file file',
                'read options from file',
                'this should evaluate to a ruby hash.',
                'cli optons are given precedence.' do |file|
          register_arg( :options_file, file )
        end

        opts.on '--type type',
                'one of git or pe', 
                'used to determine underlying path structure of puppet install',
                'defaults to pe' do |type|
          register_arg( :type, type )
        end

        opts.on '--helper my/helper.rb',
                'ruby file evaluated prior to tests',
                '(a la spec_helper)' do |one_or_more_helpers|
          register_arg( :helper, one_or_more_helpers )
        end

        opts.on  '--load-path my/script-dir/',
                 'add paths to load_path'  do |one_or_more_directories|
          register_arg( :load_path, one_or_more_directories )
        end

        opts.on  '-t', '--tests my/test.rb',
                 'execute tests from paths and files' do |one_or_more_tests|
          register_arg( :tests, one_or_more_tests )
        end

        opts.on '--pre-suite my/setup.rb',
                'path to project specific steps to be run before testing' do |one_or_more_pre_suites|
          register_arg( :pre_suite, one_or_more_pre_suites )
        end

        opts.on '--post-suite my/teardown.rb',
                'path to project specific steps to be run after testing' do |one_or_more_post_suites|
          register_arg( :post_suite, one_or_more_post_suites )
        end

        opts.on '--[no-]provision',
                'do not provision vm images before testing',
                '(default: true)' do |bool|
          register_arg( :provision, bool )
        end

        opts.on '--[no-]preserve-hosts',
                'preserve cloud instances' do |bool|
          register_arg( :preserve_hosts, bool )
        end

        opts.on '--root-keys',
                'install puppetlabs pubkeys for superuser',
                '(default: false)' do |bool|
          register_arg( :root_keys, bool )
        end

        opts.on '--keyfile /path/to/ssh/key',
                'specify alternate ssh key',
                '(default: ~/.ssh/id_rsa)' do |key|
          register_arg( :keyfile, key )
        end


        opts.on '-i uri', '--install uri',
                'install a project repo/app on the suts', 
                'provide full git uri or use short form keyword/name',
                'supported keywords: puppet, facter, hiera, hiera-puppet' do |one_or_more_install_repos|
          register_arg( :install, one_or_more_install_repos )
        end

        opts.on('-m', '--modules uri', 'select puppet module git install uri') do |one_or_more_modules|
          register_arg( :modules, one_or_more_modules )
        end

        opts.on '-q', '--[no-]quiet',
                'do not log output to stdout',
                '(default: false)' do |bool|
          register_arg( :quiet, bool )
        end

        opts.on '-x', '--[no-]xml',
                'emit junit xml reports on tests',
                '(default: false)' do |bool|
          register_arg( :xml, bool )
        end

        opts.on '--[no-]color',
                'do not display color in log output',
                '(default: true)' do |bool|
          register_arg( :color, bool )
        end

        opts.on '--[no-]debug',
                'enable full debugging',
                '(default: false)' do |bool|
          register_arg( :debug, bool )
        end

        opts.on  '-d', '--[no-]dry-run',
                 'report what would happen on targets',
                 '(default: false)' do |bool|
          register_arg( :dry_run, bool )

          $dry_run = bool # hate
        end

        opts.on '--fail-mode [mode]',
                'how should the harness react to errors/failures',
                'possible values:',
                'fast (skip all subsequent tests, cleanup, exit)',
                'stop (skip all subsequent tests, do no cleanup, exit immediately)'  do |mode|
          register_arg( :fail_mode, mode )
        end

        opts.on '--[no-]ntp',
                'sync time on suts before testing',
                '(default: false)' do |bool|
          register_arg( :timesync, bool )
        end

        opts.on '--repo-proxy',
                'proxy packaging repositories on ubuntu, debian and solaris-11',
                '(default: false)' do
          register_arg( :repo_proxy, true )
        end

        opts.on '--add-el-extras',
                'add epel repository to E.L. derivative hosts',
                '(default: false)' do
          register_arg( :add_el_extras, true )
        end

        opts.on('--help', 'display this screen' ) do |yes|
          register_arg( :print_help, yes )
        end
      end
    end
  end
end
