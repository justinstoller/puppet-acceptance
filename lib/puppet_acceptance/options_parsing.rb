module PuppetAcceptance
  class Options
    GITREPO = 'git://github.com/puppetlabs'

    DEFAULTS = {
      :config => nil,
      :options_file => nil,
      :type => 'pe',
      :helper => [],
      :load_path => [],
      :tests => [],
      :pre_suite => [],
      :post_suite => [],
      :provision => true,
      :preserve_hosts => false,
      :root_keys => false,
      :keyfile => "#{env['home']}/.ssh/id_rsa",
      :install => [],
      :modules => [],
      :quiet => false,
      :xml => false,
      :color => true,
      :debug => false,
      :dry_run => false,
      :fail_mode => nil,
      :timesync => false,
      :repo_proxy => false,
      :add_el_extras => false
    }

    def self.parse_args( arguments )
      instance = new( arguments )
      instance.register_cli_options!
      instance.parse_args!
      instance.merge_all_options!
      instance.munge_options!
      instance.validate_options!
      instance.list_options
    end

    def initialize( arguments )
      @arguments = arguments
      @no_args   = arguments.empty?
      @options   = {}
    end

    def parse_args( args = @arguments )
      optparse.parse( args )
    end

    def munge_options!( options = @options )
      # we have use the @no_args var because optparse consumes argv as it parses
      # so we have to check the value of argv at the begining of the method,
      # let the options be set, then output usage.
      if options[:print_help] or @no_args
        puts optparse
        exit
      end

      options[:helper]     = munge_possible_arg_list( options[:helper]     )
      options[:load_path]  = munge_possible_arg_list( options[:load_path]  )
      options[:tests]      = munge_possible_arg_list( options[:tests]      )
      options[:pre_suite]  = munge_possible_arg_list( options[:pre_suite]  )
      options[:post_suite] = munge_possible_arg_list( options[:post_suite] )
      options[:install]    = munge_possible_arg_list( options[:install]    )
      options[:modules]    = munge_possible_arg_list( options[:modules]    )

      options[:install] = parse_install_options( options[:install] )

      options[:pre_suite]  = file_list( options[:pre_suite]  )
      options[:post_suite] = file_list( options[:post_suite] )
      options[:tests]      = file_list( options[:tests]      )

      options
    end

    def merge_all_options!( options = @options )
      options_from_file = parse_options_file( options[:options_file] )

      # merge in the options that we read from the file
      options = options_from_file.merge( options )
      # merge in defaults
      options = DEFAULTS.merge( options )

      options
    end

    def list_options
      @logger.debug("Options")
      @options.each do |opt, val|
        if val and val != []
          @logger.debug("\t#{opt.to_s}:")
          if val.kind_of?(Array)
            val.each do |v|
              @logger.debug("\t\t#{v.to_s}")
            end
          else
            @logger.debug("\t\t#{val.to_s}")
          end
        end
      end
    end

    def validate_options!( options = @options )
      if options[:type] !~ /(pe)|(git)/
        raise ArgumentError.new("--type must be one of pe or git, not '#{options[:type]}'")
      end

      unless ["fast", "stop", nil].include?(options[:fail_mode])
        raise ArgumentError.new("--fail-mode must be one of fast, stop")
      end

      unless options[:config]
        report_and_raise(
          @logger,
          RuntimeError.new("Argh!  There is no default for Config, specify one (-c or --config)!"),
          "CLI: initialize")
      end

      unless File.exists?( options[:options_file])
        raise ArgumentError, "specified options file '#{options[:options_file]}' does not exist!"
      end
    end

    # returns deinitely_a_list :)
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

    def parse_options_file(options_file_path)
      options_file_path = File.expand_path(options_file_path)
      # this eval will allow the specified options file to have access to our
      #  scope.  it is important that the variable 'options_file_path' is
      #  accessible, because some existing options files (e.g. puppetdb) rely on
      #  that variable to determine their own location (for use in 'require's, etc.)
      result = eval(File.read(options_file_path))
      unless result.is_a? Hash
        raise ArgumentError, "options file '#{options_file_path}' must return a hash!"
      end

      result
    end

    # What the hell is this about?
    def repo?
      GITREPO
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

    def register_cli_options!
      optparse = OptionParser.new do|opts|
        # set a banner
        opts.banner = "usage: #{file.basename($0)} [options...]"

        opts.on '-c', '--config file',
                'use configuration file' do |file|
          @options[:config] = file
        end

        opts.on '-o', '--options-file file',
                'read options from file',
                'this should evaluate to a ruby hash.',
                'cli optons are given precedence.' do |file|
          @options[:options_file] = file
        end

        opts.on '--type type',
                'one of git or pe', 
                'used to determine underlying path structure of puppet install',
                'defaults to pe' do |type|
          @options[:type] = type
        end

        opts.on '--helper path/to/script',
                'ruby file evaluated prior to tests',
                '(a la spec_helper)' do |one_or_more_helpers|
          @options[:helper] = one_or_more_helpers
        end

        opts.on  '--load-path /path/to/dir,/additional/dir/paths',
                 'add paths to load_path'  do |one_or_more_directories|
          @options[:load_path] = one_or_more_directories
        end

        opts.on  '-t', '--tests /path/to/dir,/additiona/dir/paths,/path/to/file.rb',
                 'execute tests from paths and files' do |one_or_more_tests|
          @options[:tests] = one_or_more_tests
        end

        opts.on '--pre-suite /pre-suite/dir/path,/additional/dir/paths,/path/to/file.rb',
                'path to project specific steps to be run before testing' do |one_or_more_pre_suites|
          @options[:pre_suite] = one_or_more_pre_suites
        end

        opts.on '--post-suite /post-suite/dir/path,/optional/additonal/dir/paths,/path/to/file.rb',
                'path to project specific steps to be run after testing' do |one_or_more_post_suites|
          @options[:post_suite] = one_or_more_post_suites
        end

        opts.on '--[no-]provision',
                'do not provision vm images before testing',
                '(default: true)' do |bool|
          @options[:provision] = bool
        end

        opts.on '--[no-]preserve-hosts',
                'preserve cloud instances' do |bool|
          @options[:preserve_hosts] = bool
        end

        opts.on '--root-keys',
                'install puppetlabs pubkeys for superuser',
                '(default: false)' do |bool|
          @options[:root_keys] = bool
        end

        opts.on '--keyfile /path/to/ssh/key',
                'specify alternate ssh key',
                '(default: ~/.ssh/id_rsa)' do |key|
          @options[:keyfile] = key
        end


        opts.on '-i uri', '--install uri',
                'install a project repo/app on the suts', 
                'provide full git uri or use short form keyword/name',
                'supported keywords: puppet, facter, hiera, hiera-puppet' do |one_or_more_install_repos|
          @options[:install] = one_or_more_install_repos
        end

        opts.on('-m', '--modules uri', 'select puppet module git install uri') do |one_or_more_modules|
          @options[:modules] = one_or_more_modules
        end

        opts.on '-q', '--[no-]quiet',
                'do not log output to stdout',
                '(default: false)' do |bool|
          @options[:quiet] = bool
        end

        opts.on '-x', '--[no-]xml',
                'emit junit xml reports on tests',
                '(default: false)' do |bool|
          @options[:xml] = bool
        end

        opts.on '--[no-]color',
                'do not display color in log output',
                '(default: true)' do |bool|
          @options[:color] = bool
        end

        opts.on '--[no-]debug',
                'enable full debugging',
                '(default: false)' do |bool|
          @options[:debug] = bool
        end

        opts.on  '-d', '--[no-]dry-run',
                 'report what would happen on targets',
                 '(default: false)' do |bool|
          @options[:dry_run] = bool
          $dry_run = bool
        end

        opts.on '--fail-mode [mode]',
                'how should the harness react to errors/failures',
                'possible values:',
                'fast (skip all subsequent tests, cleanup, exit)',
                'stop (skip all subsequent tests, do no cleanup, exit immediately)'  do |mode|
          @options[:fail_mode] = mode
        end

        opts.on '--[no-]ntp',
                'sync time on suts before testing',
                '(default: false)' do |bool|
          @options[:timesync] = bool
        end

        opts.on '--repo-proxy',
                'proxy packaging repositories on ubuntu, debian and solaris-11',
                '(default: false)' do
          @options[:repo_proxy] = true
        end

        opts.on '--add-el-extras',
                'add extra packages for enterprise linux (epel) repository to el-* hosts',
                '(default: false)' do
          @options[:add_el_extras] = true
        end

        opts.on('--help', 'display this screen' ) do |yes|
          @options[:print_help] = yes
        end
      end
    end
  end
end
