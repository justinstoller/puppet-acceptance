module PuppetAcceptance
  module Config
    class Munger
      FILES      = [ :pre_suite, :tests, :post_suite, :helper,
                     :options_file, :config, :keyfile                       ]

      LISTS      = [ :helper, :load_path, :pre_suite, :tests, :post_suite,
                     :install, :modules                                     ]

      FILE_LISTS = FILES & LISTS

      GITREPO = 'git://github.com/puppetlabs'

      MUNGING_OPERATIONS = [ :proper_options_to_lists, :populate_file_lists,
                             :expand_file_paths, :expand_uri_aliases,
                             :convert_legacy_host_config, :convert_legacy_fog_info ]


      def munge( unmunged_configuration, munging_operations = MUNGING_OPERATIONS )
        starting_configuration = unmunged_configuration.dup

        munging_operations.inject( starting_configuration ) do |configuration, munging_operation|
          self.send( munging_operation, configuration )
        end
      end

      def proper_options_to_lists( options, list_options = LISTS )
        list_options.inject( options.dup ) do |local_opts, list|
          if local_opts.exists?( list )
            local_opts.merge( { list => ensure_list( local_opts[list] ) } )
          else
            local_opts
          end
        end
      end

      def populate_file_lists( options, file_lists = FILE_LISTS )
        file_lists.inject( options.dup ) do |local_options, file_list|
          if local_options.exists?( file_list )
            local_options.merge(
              { file_list => populate_file_list( local_options[file_list] ) }
            )
          else
            local_options
          end
        end
      end

      def expand_file_paths( options, file_options = FILES )
        file_options.inject( options.dup ) do |local_opts, file_opt|
          if local_opts.exists?( file_opt )
            if local_opts[file_opt].is_a? Array
              local_opts.merge( { file_opt => local_opts[file_opt].map {|f| File.expand_path( f ) } } )
            else
              local_opts.merge( { file_opt => File.expand_path( local_opts[file_opt] ) } )
            end
          else
            local_opts
          end
        end
      end

      def expand_uri_aliases( options )
        if options.exists?( :install )
          options.merge( { :install => expand_to_uris( options[:install] ) } )
        else
          options
        end
      end

      def ensure_list( possibly_a_list )
        case possibly_a_list
        when Array
          return possibly_a_list
        when String
          return possibly_a_list.split( ',' )
        else
          return Array( possibly_a_list )
        end
      end

      def populate_file_list( paths )
        return [] if paths.empty?

        return paths.map do |root|
          if File.file? root then
            root
          else
            Dir.glob( File.join(root, "**/*.rb") ).
              select {|f| File.file?( f ) }
          end
        end.flatten
      end

      def expand_to_uris( install_options )
        install_options.map do |option|
          rev = option.split('/', 2)[1]
          case option
            when /^puppet\//
              "#{GITREPO}/puppet.git##{rev}"
            when /^facter\//
              "#{GITREPO}/facter.git##{rev}"
            when /^hiera\//
              "#{GITREPO}/hiera.git##{rev}"
            when /^hiera-puppet\//
              "#{GITREPO}/hiera-puppet.git##{rev}"
          end
        end
      end

      # host
      # provisioner
      # connection
      # check
      # software
      # runner
      def convert_legacy_host_config( configuration )
        { :host        => configuration['HOSTS'],
          :provisioner => {
            :vcloud => {
              :datastore     => configuration['CONFIG']['datastore'],
              :resource_pool => configuration['CONFIG']['resourcepool'],
              :folder        => configuration['CONFIG']['folder']
            }
          },
          :connection => {
            :ssh => configuration['CONFIG']['ssh']
          }
        }
      end

      def convert_legacy_fog_info( configuration )
        { :provisioner => {
            :default => configuration[:default]
          }
        }
      end

      ##########################################################
      # This method highlights two issues
      #   a) How the hell are we getting puppet_enterprise_version from the file parser
      #   b) What will be the roll out plan for this within CI?
      #   c) What other objects depend upon this in the harness?
      #   d) should this hash still exist for the legacy tests' sake
      #
      #   And by two I apparently mean four
      #
      # Steps to complete moving forward
      #   1. Complete new configuration hierarcy
      #   2. Ensure the pe_version info can be returned as a Config::Value
      #   3. Set up munger in `convert_legacy_host_config` to take a host
      #         config and return the new hierarchy
      #   4. Set up munger to munge pe_version
      #   5. Set up munger to munge pe_version-win
      def set_hosts_config_defaults( config )
        # We should merge this a default hash??
        ## Make sure the roles array is present for all hosts
        #config['HOSTS'].each_key do |host|
        #  config['HOSTS'][host]['roles'] ||= []
        #end
        if is_pe
          config['CONFIG']['pe_dir']           = puppet_enterprise_dir
          config['CONFIG']['pe_ver']           = puppet_enterprise_version
          config['CONFIG']['pe_ver_win']       = puppet_enterprise_version( :type )
        end

        return config
      end

      def decide_if_pe( options )
        is_pe = options[:type] =~ /pe/ ? true : false
        options.merge( { :is_pe => is_pe } )
      end

    end
  end
end
