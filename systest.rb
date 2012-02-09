#!/usr/bin/env ruby

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'lib/options'
require_relative 'lib/test_config'
require_relative 'lib/test_suite'
require_relative 'lib/network'
require_relative 'lib/log'

trap(:INT) do
  Log.error "Interrupt received; exiting..."
  exit(1)
end

options = Options.parse_args

unless options[:config] then
  fail "Argh!  There is no default for Config, specify one!"
end

Log.debug "Using Config #{options[:config]}"

config = TestConfig.load_file(options[:config])

if options[:noinstall]
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/post"] })
elsif options[:upgrade]
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/pe_upgrade", "setup/post"] })
elsif options[:type] == 'cp_pe'
  setup_options = options.merge({ :random => false,
                                  :tests => ["setup/early/01-vmrun.rb", "setup/cp_pe"] })
elsif options[:type] == 'pe_aws'
  setup_options = options.merge({ :random => false,
                                  :tests => ["setup/pe_aws"] })
elsif options[:uninstall]
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/pe_uninstall/#{options[:uninstall]}"] })
else
  setup_options = options.merge({ :random => false,
                                  :tests  => ["setup/early", "setup/#{options[:type]}", "setup/post"] })
end

# Generate hosts
network = Network.new(config)

begin
  # Run the harness for install
  TestSuite.new('setup', network, setup_options, config, TRUE).run_and_exit_on_failure

  # Run the tests
  unless options[:installonly] then
    TestSuite.new('acceptance', network, options, config).run_and_exit_on_failure
  end
ensure
  network.each {|host| host.close }
end

Log.notify "systest completed successfully, thanks."
exit 0
