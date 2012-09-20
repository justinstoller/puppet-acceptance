require 'rubygems' unless defined?(Gem)
begin
  require 'rbvmomi'
rescue LoadError
  fail_test "Unable to load RbVmomi, please ensure its installed"
end

class VsphereHelper

  TYPES = {
    :vm       => 'VirtualMachine',
    :template => 'VirtualMachine',
    :rpool    => 'ResourcePool',
    :folder   => 'Folder'
  }

  def initialize vInfo = {}
    @connection = RbVmomi::VIM.connect :host     => vInfo[:server],
                                       :user     => vInfo[:user],
                                       :password => vInfo[:pass],
                                       :insecure => true

    @collector = @connection.propertyCollector
  end

  def find_snapshot vm, snapname
    search_child_snaps vm.snapshot.rootSnapshotList, snapname
  end

  def search_child_snaps tree, snapname
    snapshot = nil
    tree.each do |child|
      if child.name == snapname
        snapshot ||= child.snapshot
      else
        snapshot ||= search_child_snaps child.childSnapshotList, snapname
      end
    end
    snapshot
  end

  # an easier wrapper around the horrid PropertyCollector interface,
  # necessary for searching VMs in all Datacenters that may be nested
  # within folders of arbitrary depth
  # usage: find :template, :name => [ 'Debian-6-64-PE', 'Debian-6-32-PE' ]
  # retuns an array of ManagedObjects with those properties
  def find supplied_type, properties_hash,
           connection = @connection, collector = @collector

    properties_hash['config.template'] = true if supplied_type == :template
    type = TYPES[supplied_type] ? TYPES[supplied_type] : supplied_type

    properties_array = properties_hash.keys
    container_view = get_container_view_for type, connection

    traversal = container_traversal
    object_set = [ object_spec( container_view, traversal ) ]

    prop_set = [{ :pathSet => properties_array,
                 :type    => type               }]

    filter = filter_spec object_set, prop_set

    get_objects_with properties_hash, filter
  end

  def filter_spec object_set, prop_set
    {
      :specSet => [{
        :objectSet => object_set,
        :propSet   => prop_set
      }],
      :options => { :maxObjects => nil }
    }
  end

  def container_traversal
    RbVmomi::VIM::TraversalSpec.new({
        :name => 'gettingAllTheGoods',
        :path => 'view',
        :skip => false,
        :type => 'ContainerView'
    })
  end

  def object_spec object, traversal
    selectSet = [ traversal ].flatten
    {
      :obj => object,
      :skip => true,
      :selectSet => selectSet
    }
  end

  def get_objects_with properties, filter, collector = @collector
    # this is ugly, resource intensive and slow
    # but it's faster because I left out the Oxford comma
    results = collector.RetrievePropertiesEx( filter )

    objects = []
    results.objects.each do |result|
      properties_array.each do |property|
        if properties_hash[property].include?(result.propSet.first.val)
          objects << result.obj
        end
      end
    end
    objects.uniq
  end

  def get_container_view_for types, connection = @connection
    types_array = [ types ].flatten
    viewManager = connection.serviceContent.viewManager
    viewManager.CreateContainerView({
      :container => connection.serviceContent.rootFolder,
      :recursive => true,
      :type      => types_array
    })
  end
end

