# We want to "parse" the options that come in from both the CLI and/or Options File.
# Then we want to munge each set of inputs?
# Then merge and validate the result?
# Everyone else probably new this, but technically an argument is the attempt
# to persuade while an option is the right to do something. The harness has
# options, the user gives any number of arguments (in a variety of formats)
# to persuade the harness to act in a certain way
module PuppetAcceptance
  class Options
    GITREPO = 'git://github.com/puppetlabs'

    DEFAULTS = {
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
      :keyfile        => "#{env['home']}/.ssh/id_rsa",
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
      :add_el_extras  => false
    }

    def parse_args( arguments )
      cli_args_parser = register_cli_options
      parsed_cli_args = parse_cli_args( cli_args_parser, arguments )

      if parse_cli_args[:print_help] or arguments.empty?
        puts cli_args_parser
        exit # We should have a real way to say we want to terminate the program....
      end

      locations        = Array( parsed_cli_args[:options_file] || DEFAULTS[:options_file] )
      args_location    = locations.find {|loc| File.exists?( File.expand_path( loc )) }
      parsed_file_args = parse_file_args( args_location )

      munged_cli_args  = munge_args( parsed_cli_args  )
      munged_file_args = munge_args( parsed_file_args )

      merged_args = merge_args( DEFAULTS, munged_file_args, munged_cli_args )

      validate_args( merged_args )

      return merged_args
    end

    def parse_cli_args( parser, args )
      args_hash = {}

      set_args_hash( args_hash )
      parser.parse( args )
      unset_args_hash

      return args_hash
    end

    def parse_args_file(options_file_path)
      options_file_path = File.expand_path( options_file_path )
      # this eval will allow the specified options file to have access to our
      # scope.  it is important that the variable 'options_file_path' is
      # accessible, because some existing options files (e.g. puppetdb) rely on
      # that variable to determine their own location (for use in 'require's, etc.)
      result = eval( File.read( options_file_path ) )

      return result
    end

    def munge_args( options )
      munged_opts = opts.dub
      munged_opts[:helper]     = munge_possible_arg_list( options[:helper]     )
      munged_opts[:load_path]  = munge_possible_arg_list( options[:load_path]  )
      munged_opts[:tests]      = munge_possible_arg_list( options[:tests]      )
      munged_opts[:pre_suite]  = munge_possible_arg_list( options[:pre_suite]  )
      munged_opts[:post_suite] = munge_possible_arg_list( options[:post_suite] )
      munged_opts[:install]    = munge_possible_arg_list( options[:install]    )
      munged_opts[:modules]    = munge_possible_arg_list( options[:modules]    )

      munged_opts[:install] = parse_install_options( munged_opts[:install] )

      munged_opts[:pre_suite]  = file_list( munged_opts[:pre_suite]  )
      munged_opts[:post_suite] = file_list( munged_opts[:post_suite] )
      munged_opts[:tests]      = file_list( munged_opts[:tests]      )

      return munged_opts
    end

    def merge_args( defaults, args_from_file, args_from_cli )
      user_supplied_args = args_from_file.merge( args_from_cli )
      options = defaults.merge( user_supplied_args )

      return options
    end

    def pretty_print_args( args )
      pretty = [ "Options" ] +
        args.map do |arg, val|
          if val and val != []
            [ "\t#{opt.to_s}:" ] +
            if val.kind_of?(Array)
              val.map do |v|
                [ "\t\t#{v.to_s}" ]
              end
            else
              [ "\t\t#{val.to_s}" ]
            end
          end
        end

      return pretty.join( "\n" )
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

      unless args[:options_file].empty
        unless File.exists?( File.expand_path( args[:options] ) )
          raise ArgumentError.new(
            "Specified options file '#{args[:options_file]}' does not exist!" )
        end
      end
    end

    def munge_possible_arg_lists( possibly_a_list )
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
              raise ArgumentError, "empty directory used as an option (#{root})!"
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

    def register_arg( name, value )
      @current_arg_hash[name] = value
    end

    def register_cli_options!
      optparse = OptionParser.new do |opts|
        # set a banner
        opts.banner = "Usage: #{file.basename($0)} [options...]"

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

        opts.on '--helper path/to/script',
                'ruby file evaluated prior to tests',
                '(a la spec_helper)' do |one_or_more_helpers|
          register_arg( :helper, one_or_more_helpers )
        end

        opts.on  '--load-path /path/to/dir,/additional/dir/paths',
                 'add paths to load_path'  do |one_or_more_directories|
          register_arg( :load_path, one_or_more_directories )
        end

        opts.on  '-t', '--tests /path/to/dir,/additiona/dir/paths,/path/to/file.rb',
                 'execute tests from paths and files' do |one_or_more_tests|
          register_arg( :tests, one_or_more_tests )
        end

        opts.on '--pre-suite /pre-suite/dir/path,/additional/dir/paths,/path/to/file.rb',
                'path to project specific steps to be run before testing' do |one_or_more_pre_suites|
          register_arg( :pre_suite, one_or_more_pre_suites )
        end

        opts.on '--post-suite /post-suite/dir/path,/optional/additonal/dir/paths,/path/to/file.rb',
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
                'add extra packages for enterprise linux (epel) repository to el-* hosts',
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
