%w(windows unix aix).each do |os|
  begin
    require "puppet_acceptance/hosts/#{os}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), os))
  end
end

module PuppetAcceptance
  module Hosts
    module Abstraction

      def self.create name, options, config
        my = case config['HOSTS'][name]['platform']
             when /windows/
               PuppetAcceptance::Hosts::Windows::Host.new name, options, config
             when /aix/
               PuppetAcceptance::Hosts::AIX::Host.new name, options, config
             else
               PuppetAcceptance::Hosts::Unix::Host.new name, options, config
             end

        my.connection = SshConnection.connect( my['ip'] || my.name,
                                               my['user'],
                                               my['ssh'] )
        return my
      end
    end
  end
end
