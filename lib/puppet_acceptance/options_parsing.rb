module puppetacceptance
  class options
    gitrepo = 'git://github.com/puppetlabs'

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

    def self.options
      return @options
    end

    def self.repo?
      gitrepo
    end

    def self.parse_install_options(install_opts)
      install_opts.map! { |opt|
        case opt
          when /^puppet\//
            opt = "#{gitrepo}/puppet.git##{opt.split('/', 2)[1]}"
          when /^facter\//
            opt = "#{gitrepo}/facter.git##{opt.split('/', 2)[1]}"
          when /^hiera\//
            opt = "#{gitrepo}/hiera.git##{opt.split('/', 2)[1]}"
          when /^hiera-puppet\//
            opt = "#{gitrepo}/hiera-puppet.git##{opt.split('/', 2)[1]}"
        end
        opt
      }
      install_opts
    end

    def self.file_list(paths)
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

    def self.parse_args
      return @options if @options

      @no_args = argv.empty? ? true : false

      @options = {}
      @options_from_file = {}

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
          @options_from_file = parse_options_file file
        end

        opts.on '--type type',
                'one of git or pe', 
                'used to determine underlying path structure of puppet install',
                'defaults to pe' do |type|
          @options[:type] = type
        end

        opts.on '--helper path/to/script',
                'ruby file evaluated prior to tests',
                '(a la spec_helper)' do |script|
          @options[:helper] = []
          if script.is_a?(array)
            @options[:helper] += script
          elsif script =~ /,/
            @options[:helper] += script.split(',')
          else
            @options[:helper] << script
          end
        end

        opts.on  '--load-path /path/to/dir,/additional/dir/paths',
                 'add paths to load_path'  do |value|
          @options[:load_path] = []
          if value.is_a?(array)
            @options[:load_path] += value
          elsif value =~ /,/
            @options[:load_path] += value.split(',')
          else
            @options[:load_path] << value
          end
        end

        opts.on  '-t', '--tests /path/to/dir,/additiona/dir/paths,/path/to/file.rb',
                 'execute tests from paths and files' do |value|
          @options[:tests] = []
          if value.is_a?(array)
            @options[:tests] += value
          elsif value =~ /,/
            @options[:tests] += value.split(',')
          else
            @options[:tests] << value
          end
          @options[:tests] = file_list(@options[:tests])
          if @options[:tests].empty?
            raise ArgumentError, "no tests to run!"
          end
        end

        opts.on '--pre-suite /pre-suite/dir/path,/additional/dir/paths,/path/to/file.rb',
                'path to project specific steps to be run before testing' do |value|
          @options[:pre_suite] = []
          if value.is_a?(array)
            @options[:pre_suite] += value
          elsif value =~ /,/
            @options[:pre_suite] += value.split(',')
          else
            @options[:pre_suite] << value
          end
          @options[:pre_suite] = file_list(@options[:pre_suite])
          if @options[:pre_suite].empty?
            raise ArgumentError, "empty pre-suite!"
          end
        end

        opts.on '--post-suite /post-suite/dir/path,/optional/additonal/dir/paths,/path/to/file.rb',
                'path to project specific steps to be run after testing' do |value|
          @options[:post_suite] = []
          if value.is_a?(array)
            @options[:post_suite] += value
          elsif value =~ /,/
            @options[:post_suite] += value.split(',')
          else
            @options[:post_suite] << value
          end
          @options[:post_suite] = file_list(@options[:post_suite])
          if @options[:post_suite].empty?
            raise ArgumentError, "empty post-suite!"
          end
        end

        opts.on '--[no-]provision',
                'do not provision vm images before testing',
                '(default: true)' do |bool|
          @options[:provision] = bool
        end

        opts.on '--[no-]preserve-hosts',
                'preserve cloud instances' do |value|
          @options[:preserve_hosts] = value
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
                'supported keywords: puppet, facter, hiera, hiera-puppet' do |value|
          @options[:install] = []
          if value.is_a?(array)
            @options[:install] += value
          elsif value =~ /,/
            @options[:install] += value.split(',')
          else
            @options[:install] << value
          end
          @options[:install] = parse_install_options(@options[:install])
        end

        opts.on('-m', '--modules uri', 'select puppet module git install uri') do |value|
          @options[:modules] ||= []
          @options[:modules] << value
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
          puts opts
          exit
        end
      end

      optparse.parse!

      # we have use the @no_args var because optparse consumes argv as it parses
      # so we have to check the value of argv at the begining of the method,
      # let the options be set, then output usage.
      puts optparse if @no_args

      # merge in the options that we read from the file
      @options = @options_from_file.merge(@options)
      # merge in defaults
      @options = DEFAULTS.merge(@options)

      if @options[:type] !~ /(pe)|(git)/
        raise ArgumentError.new("--type must be one of pe or git, not '#{@options[:type]}'")
      end

      raise ArgumentError.new("--fail-mode must be one of fast, stop") unless ["fast", "stop", nil].include?(@options[:fail_mode])

      @options
    end

    def self.parse_options_file(options_file_path)
      options_file_path = File.expand_path(options_file_path)
      unless File.exists?(options_file_path)
        raise ArgumentError, "specified options file '#{options_file_path}' does not exist!"
      end
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
  end
end
