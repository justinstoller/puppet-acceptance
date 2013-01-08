module PuppetAcceptance
  module Hosts
    module Unix
      module Exec
        include PuppetAcceptance::CommandFactory

        def echo(msg, abs=true)
          (abs ? '/bin/echo' : 'echo') + " #{msg}"
        end

        def touch(file, abs=true)
          (abs ? '/bin/touch' : 'touch') + " #{file}"
        end

        def path
          '/bin:/usr/bin'
        end
      end
    end
  end
end
