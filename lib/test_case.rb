class TestCase
  require 'benchmark'
  require 'stringio'
  require 'test/unit/assertions'
  require_relative 'log'

  class SkippedTest < StandardError; end

  include Test::Unit::Assertions

  attr_reader :version, :config, :options, :path, :fail_flag, :usr_home,
    :test_status, :exception, :runtime

  def initialize(network, config, options={}, path=nil)
    @version = config['VERSION']
    @config  = config['CONFIG']
    @network   = network
    @options = options
    @path    = path
    @usr_home = ENV['HOME']
    @test_status = :pass
    @exception = nil
    @runtime = nil
    #
    # We put this on each wrapper (rather than the class) so that methods
    # defined in the tests don't leak out to other tests.
    class << self
      def run_test
        begin
          test = File.read(path)
          eval test, nil, path, 1
        rescue TestCase::SkippedTest
        rescue error_class => e
          @test_status = :fail
          @exception   = e
        rescue StandardError, ScriptError => e
          e.backtrace.each { |line| Log.error(line) }
          @test_status = :error
          @exception   = e
        end
        return self
      end
    end
  end

  def error_class
    if defined?(Test::Unit) && !defined?(MiniTest)
      Test::Unit::AssertionFailedError
    else
      MiniTest::Assertion
    end
  end

  def to_hash
    hash = {}
    hash['HOSTS'] = {}
    hash['CONFIG'] = @config
    @network.each do |host|
      hash['HOSTS'][host.name] = host.overrides
    end
    hash
  end

  #
  # Annotations
  #
  def step(step_name,&block)
    Log.notify "  * #{step_name}"
    yield if block
  end

  #
  # Basic operations
  #
  def hosts
    @network.hosts
  end

  def master
    @network.master
  end

  def dashboard
    @network.dashboard
  end

  def agents
    @network.agents
  end

  def on(host, command, options={}, &block)
    @network.on host, command, options, &block
  end

  def scp_to(host, from_path, to_path, options={})
    @network.scp_to host, from_path, to_path, options
  end

  def pass_test(msg)
    Log.notify msg
  end

  def skip_test(msg)
    Log.notify "Skip: #{msg}"
    @test_status = :skip
    raise TestCase::SkippedTest
  end

  def fail_test(msg)
    fail msg
  end

  #
  # Macros
  #
  def facter(*args)
    FacterCommand.new(*args)
  end

  def puppet(*args)
    PuppetCommand.new(*args)
  end

  def puppet_resource(*args)
    PuppetCommand.new(:resource,*args)
  end

  def puppet_doc(*args)
    PuppetCommand.new(:doc,*args)
  end

  def puppet_kick(*args)
    PuppetCommand.new(:kick,*args)
  end

  def puppet_cert(*args)
    PuppetCommand.new(:cert,*args)
  end

  def puppet_apply(*args)
    PuppetCommand.new(:apply,*args)
  end

  def puppet_master(*args)
    PuppetCommand.new(:master,*args)
  end

  def puppet_agent(*args)
    PuppetCommand.new(:agent,*args)
  end

  def puppet_filebucket(*args)
    PuppetCommand.new(:filebucket,*args)
  end

  def apply_manifest_on(host, manifest, options={}, &block)
    @network.apply_manifest_on host, manifest, options, &block
  end

  def run_script_on(host, script, &block)
    @network.run_script_on host, script, &block
  end

  def run_agent_on(host, arg='--no-daemonize --verbose --onetime --test', options={}, &block)
    @network.run_agents_on host, arg, options, options, &block
  end

  def run_cron_on(host, action, user, entry="", &block)
    @network.run_cron_on host, action, user, entry, &block
  end

  def with_master_running_on(host, arg='--daemonize', &block)
    @network.with_master_running_on host, arg, &block
  end

  def poll_master_until(host, verb)
    @network.poll_master_until host, verb
  end

  def create_remote_file(hosts, file_path, file_content)
    @network.create_remote_file hosts, file_path, file_content
  end

  def with_standard_output_to_logs &block
    Log.warn "stdout is now #{$stdout}"
    stdout = ''
    old_stdout = $stdout
    $stdout = StringIO.new(stdout, 'w')

    stderr = ''
    old_stderr = $stderr
    $stderr = StringIO.new(stderr, 'w')

    result = yield if block_given?

    $stdout = old_stdout
    $stderr = old_stderr

    stdout.each_line { |line| Log.notify(line) }
    stderr.each_line { |line| Log.warn(line) }

    return result
  end

private

  def test_name(name, &block)
    Log.notify name
    yield if block_given?
  end

end
