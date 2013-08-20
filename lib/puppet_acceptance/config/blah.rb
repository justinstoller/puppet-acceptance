class Manager

  attr_reader :input_types, :munger, :parser, :validator, :merger

  def initialize( input_types = [ :cli, :env, :options_file, :hosts_config, :fog, :pe_version ],
                  merger      = Merger.new,
                  parser      = Parser.new,
                  validator   = Validator.new,
                  munger      = Munger.new
                )

    @input_types = input_types
    @merger      = merger
    @parser      = parser
    @validator   = validator
    @munger      = munger
  end

  def configuration_for( type, configuration_up_to_now )
    parsed_input  = parser.parse( type, configuration_up_to_now )
    valid_input   = validator.validate( parsed_input )
    configuration = munger.munge( valid_input )

    return configuration
  end

  def get_configuration
    defaults = PuppetAcceptance::Config::Value.new
    configurations = []

    inputs_types.inject( [defaults] ) do |previous_configurations, input_type|

      the_world_up_to_now = merger.merge( *previous_configurations )
      this_configuration  = configuration_for( input_type, the_world_up_to_now )

      configurations << this_connfiguration

      return previous_configurations + [this_configuration]
    end

    merged_configuration = merger.merge( *configurations )
    final_configuration = finalize( merged_configuration )

    return final_configuration
  end

end

class Parser

  attr_reader :file_parser, :cli_parser, :env_parser

  def initialize( file_parser = PuppetAcceptance::Config::FileParser.new,
                  cli_parser  = PuppetAcceptance::Config::CliParser.new,
                  env_parser  = PuppetAcceptance::Config::EnvParser.new     )

    @file_parser = file_parser
    @cli_parser  = cli_parser
    @env_parser  = env_parser
  end

  def parse( type, configuration )
    case type
    when :cli
      parse_cli_args
    when :options_file
      parse_options_file( configuration )
    when :hosts_config
      parse_hosts_config( configuration )
    when :env
      parse_env
    end
  end

  def parse_cli_args
    cli_parser.parse
  end

  def parse_options_file( configuration )
    locations = Array( configuration[:options_file] )

    locations.each do |location|
      parsed_file_args = file_parser.load_file( location )

      break unless parsed_file_args
    end

    parsed_file_args
  end

  def parse_hosts_config( configuration )
    host_config = file_parser.load_file( configuration[:config] )
  end

  def parse_env
    env_parser.parse
  end
end

class Merger

  SORT_ORDER = [ :defaults, :other, :file, :env, :cli ]

  def merge( *args )
    return args.first if args.length == 1

    sorted = sort_inputs_by( args, SORT_ORDER )

    return multi_merge( *sorted )
  end

  def sort_inputs_by( inputs, ordering )
    return inputs.sort do |input_a, input_b|
      ordering.index( input_a.type ) <=> ordering.index( input_b.type )
    end
  end

  def multi_merge( *args )
    return args.inject do |combined, new|
      combined.merge( new )
    end
  end
end

class Munger
  FILES      = [ :pre_suite, :tests, :post_suite, :helper,
                 :options_file, :config, :keyfile                       ]

  LISTS      = [ :helper, :load_path, :pre_suite, :tests, :post_suite,
                 :install, :modules                                     ]

  FILE_LISTS = FILES | LISTS

  GITREPO = 'git://github.com/puppetlabs'

  MUNGING_OPERATIONS = [ :proper_options_to_lists, :populate_file_lists,
                         :expand_file_paths, :expand_uri_aliases,
                         :convert_legacy_host_config, :convert_legacy_enterprise_info ]


  def munge( unmunged_configuration, munging_operations = MUNGING_OPERATIONS )
    starting_configuraton = unmunged_configuration.dup

    munging_operations.inject( starting_configuration ) do |configuration, munging_operation|
      self.send( munging_operation, configuration )
    end
  end

  def proper_options_to_lists( options, list_options = LISTS )
    list_options.inject( options.dup ) do |local_opts, list|
      if local_opts.exists?( list )
        local_opts.merge( { list => ensure_list( local_opts[list] ) } )
      else
        local_opts
      end
    end
  end

  def populate_file_lists( options, file_lists = FILE_LISTS )
    file_lists.inject( options.dup ) do |local_options, file_list|
      if local_options.exists?( file_list )
        local_options.merge(
          { file_list => populate_file_list( local_options[file_list] ) }
        )
      else
        local_options
      end
    end
  end

  def expand_file_paths( options, file_options = FILES )
    file_options.inject( options.dup ) do |local_opts, file_opt|
      if local_opts.exists?( file_opt )
        if local_opts[file_opt].is_a? Array
          local_opts.merge( { file_opt => local_opts[file_opt].map {|f| File.expand_path( f ) } } )
        else
          local_opts.merge( { file_opt => File.expand_path( local_opts[file_opt] ) } )
        end
      else
        local_opts
      end
    end
  end

  def expand_uri_aliases( options )
    if options.exists?( :install )
      options.merge( { :install] => expand_to_uris( options[:install] ) } )
    else
      options
    end
  end

  def ensure_list( possibly_a_list )
    case possibly_a_list
    when Array
      return possibly_a_list
    when String
      return possibly_a_list.split( ',' )
    else
      return Array( possibly_a_list )
    end
  end

  def populate_file_list( paths )
    return [] if paths.empty?

    return paths.map do |root|
      if File.file? root then
        root
      else
        Dir.glob( File.join(root, "**/*.rb") ).
          select {|f| File.file?( f ) }
      end
    end.flatten
  end

  def expand_to_uris( install_options )
    install_options.map do |option|
      rev = option.split('/', 2)[1]
      case option
        when /^puppet\//
          "#{GITREPO}/puppet.git##{rev}"
        when /^facter\//
          "#{GITREPO}/facter.git##{rev}"
        when /^hiera\//
          "#{GITREPO}/hiera.git##{rev}"
        when /^hiera-puppet\//
          "#{GITREPO}/hiera-puppet.git##{rev}"
      end
    end
  end

  # host
  # provisioner
  # connection
  # check
  # software
  # runner
  def convert_legacy_host_config( configuration )
  end

  def convert_legacy_enterprise_info( configuration )
  end

  ##########################################################
  # This method highlights two issues
  #   a) How the hell are we getting puppet_enterprise_version from the file parser
  #   b) What will be the roll out plan for this within CI?
  #   c) What other objects depend upon this in the harness?
  #   d) should this hash still exist for the legacy tests' sake
  #
  #   And by two I apparently mean four
  #
  # Steps to complete moving forward
  #   1. Complete new configuration hierarcy
  #   2. Ensure the pe_version info can be returned as a Config::Value
  #   3. Set up munger in `convert_legacy_host_config` to take a host
  #         config and return the new hierarchy
  #   4. Set up munger to munge pe_version
  #   5. Set up munger to munge pe_version-win
  #   6. Set up munger in `convert_legacy_enterprise_info` to create
  #         old 'CONFIG' hash
  def set_legacy_crap( options )
    set_hosts_config_defaults( decide_if_pe( options ) )
  end

  def set_hosts_config_defaults( config )
    # We should merge this a default hash??
    ## Make sure the roles array is present for all hosts
    #config['HOSTS'].each_key do |host|
    #  config['HOSTS'][host]['roles'] ||= []
    #end
    config['CONFIG'] ||= {}
    consoleport = ENV['consoleport'] || config['CONFIG']['consoleport'] || 443
    config['CONFIG']['consoleport']        = consoleport.to_i
    config['CONFIG']['ssh']                = PuppetAcceptance::Config::DEFAULTS[:ssh].merge(config['CONFIG']['ssh'] || {})

    if is_pe
      config['CONFIG']['pe_dir']           = puppet_enterprise_dir
      config['CONFIG']['pe_ver']           = puppet_enterprise_version
      config['CONFIG']['pe_ver_win']       = puppet_enterprise_version( :type )
    end

    return config
  end

  def decide_if_pe( options )
    is_pe = options[:type] =~ /pe/ ? true : false
    options.merge( { :is_pe => is_pe } )
  end
end
