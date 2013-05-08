module PuppetAcceptance
  class CLI
    def initialize
      @options = PuppetAcceptance::Options.parse_args
      @logger = PuppetAcceptance::Logger.new(@options)
      @options[:logger] = @logger

      if @options[:config] then
        @logger.debug "Using Config #{@options[:config]}"
      else
        fail "Argh!  There is no default for Config, specify one (-c or --config)!"
      end

      @config = PuppetAcceptance::TestConfig.new(@options[:config], @options)

      if (@options[:helper])
        require File.expand_path(@options[:helper])
      end

      @hosts =  []
      @config['HOSTS'].each_key do |name|
        @hosts << PuppetAcceptance::Host.create(name, @options, @config)
      end
    end

    def execute!
      begin
        trap(:INT) do
          @logger.warn "Interrupt received; exiting..."
          exit(1)
        end

        run_suite('pre-setup', pre_options, :fail_fast) if @options[:pre_script]
        run_suite('setup', setup_options, :fail_fast)
        run_suite('pre-suite', pre_suite_options)
        begin
          run_suite('acceptance', @options) unless @options[:installonly]
        ensure
          run_suite('post-suite', post_suite_options)
        end

      ensure
        run_suite('cleanup', cleanup_options)
        @hosts.each {|host| host.close }
      end
    end

    def run_suite(name, options, failure_strategy = false)
      if (options[:tests].empty?)
        @logger.notify("No tests to run for suite '#{name}'")
        return
      end
      PuppetAcceptance::TestSuite.new(
        name, @hosts, options, @config, failure_strategy
      ).run_and_raise_on_failure
    end

    def setup_options
      setup_opts = nil
      if @options[:noinstall]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["#{puppet_acceptance_root}/setup/early",
                      "#{puppet_acceptance_root}/setup/post"] })

      elsif @options[:upgrade]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["#{puppet_acceptance_root}/setup/early",
                      "#{puppet_acceptance_root}/setup/pe_upgrade",
                      "#{puppet_acceptance_root}/setup/post"] })

      elsif @options[:type] == 'cp_pe'
        setup_opts = @options.merge({
          :random => false,
          :tests => ["#{puppet_acceptance_root}/setup/early/01-vmrun.rb",
                     "#{puppet_acceptance_root}/setup/cp_pe"] })

      elsif @options[:type] == 'pe_aws'
        setup_opts = @options.merge({
          :random => false,
          :tests => ["#{puppet_acceptance_root}/setup/pe_aws"] })

      elsif @options[:uninstall]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["#{puppet_acceptance_root}/setup/early",
                      "#{puppet_acceptance_root}/setup/pe_uninstall/#{@options[:uninstall]}"] })

      else
        setupdir = "#{puppet_acceptance_root}/setup/#{@options[:type]}"
        setup_opts = build_suite_options("early")
        setup_opts[:tests] << setupdir if File.exists?( setupdir )
        setup_opts[:tests] << "#{puppet_acceptance_root}/setup/post"
      end
      setup_opts
    end

    def pre_options
      @options.merge({
        :random => false,
        :tests => [ "#{puppet_acceptance_root}/setup/early",
                    @options[:pre_script] ] })
    end

    def pre_suite_options
      build_suite_options('pre_suite')
    end
    def post_suite_options
      build_suite_options('post_suite')
    end
    def cleanup_options
      build_suite_options('cleanup')
    end

    def build_suite_options(phase_name)
      tests = []
      if (File.directory?("#{puppet_acceptance_root}/setup/#{phase_name}"))
        tests << "#{puppet_acceptance_root}/setup/#{phase_name}"
      end
      if (@options[:setup_dir] and
          File.directory?("#{@options[:setup_dir]}/#{phase_name}"))
        tests << "#{@options[:setup_dir]}/#{phase_name}"
      end
      @options.merge({
         :random => false,
         :tests => tests })
    end

    def puppet_acceptance_root
      @puppet_acceptance_root ||= File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
    end
  end
end
