class Network
  require_relative 'test_case/host'
  require_relative 'network_helpers'
  include Enumerable
  include NetworkHelpers

  def initialize(config)
    @hosts = config['HOSTS'].collect do |name, overrides|
      TestCase::Host.create(name, overrides, config['CONFIG'])
    end
    Log.debug "initialized network"
  end

  def each
    @hosts.each do |host|
      yield host
    end
  end

  def hosts(role = nil)
    @hosts.select { |host| role.nil? or host['roles'].include?(role) }
  end
end
