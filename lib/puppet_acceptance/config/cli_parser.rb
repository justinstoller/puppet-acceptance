require 'optparse'
require 'puppet_acceptance/config/value'

module PuppetAcceptance
  module Config
    class CliParser

      def parse( args = ARGV.dup )
        args_hash = {}

        parser = create_parser
        set_args_hash( args_hash )
        parser.parse( args )
        unset_args_hash

        return PuppetAcceptance::Config::Value.new( args_hash )
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

      def create_parser
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
end
