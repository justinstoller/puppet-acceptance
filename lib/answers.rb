class Answer
  def initialize(title = '', state = false)
    @state = ENV[title] || state
    @title = title
    @defined = true
  end

  def yes?
    @state
  end

  def defined?
    @defined
  end

  def @state.to_s
  end

  def to_s
    if @defined
      "#{@title}=#{if @state == true
                     'y'
                   elsif @state == false
                     'n'
                   else
                     @state
                   end
      }"
    else
      ''
    end
  end
end

class AnswerGroup
  require_relative 'network_helpers'
  include NetworkHelpers

  def initialize(network, host, version=nil)
    @network = network
    @version = version
    @host = host
  end

  def [](meth)
    self.send(meth.to_sym)
  end

  def host
    @host
  end

  def hosts(role = nil)
    @network.select { |host| role.nil? or host['roles'].include?(role) }
  end

  def console_name
    @console_name ||= @version =~ /^1/ ?
      'puppetdashboard' : 'puppet_enterpriseconsole'
  end

  def <<(role_module)
    extend role_module
  end

  def to_s
    out = ''
    singleton_methods.sort.each do |meth|
      out += self.send(meth.to_sym).to_s
      out += "\n"
    end
    return out
  end
end

class AnswerFile < AnswerGroup
end

module GlobalAnswers
  def agent_install
    @agent_install ||= Answer.new('q_puppetagent_install', true)
  end

  def console_install
    @console_install ||= Answer.new("q_#{console_name}_install",
      host.is_dashboard?)
  end

  def master_install
    @master_install ||= Answer.new('q_puppetmaster_install', false)
  end

  def cloud_install
    @cloud_install ||= Answer.new('q_puppet_cloud_install', true)
  end

  def install_vender_pkgs
    @install_vender_pkgs ||= Answer.new('q_vendor_packages_install', true)
  end

  def install_symlinks
    @install_symlinks ||= Answer.new('q_puppet_symlinks_install', true)
  end

  def install
    @install ||= Answer.new('q_install', true)
  end
end

module AgentAnswers
  def agent_install
    @agent_install ||= Answer.new('q_puppetagent_install', true)
  end

  def agent_name
    @agents_name ||= Answer.new('q_puppetagent_certname', $certcmd)
  end

  def agent_master
    @agents_master ||= master['answers']['master_name']
  end
end

module DashboardAnswers

  def console_install
    @console_install ||= Answer.new("q_#{console_name}_install", true)
  end

  def console_port
    @consoles_port ||= Answer.new(
      "q_#{console_name}_httpd_port",
      '443')
  end

  def console_auth_user
    @consoles_auth_user ||= Answer.new(
      "q_#{console_name}_auth_user",
      'console')
  end

  def console_auth_pass
    @consoles_auth_pass ||= Answer.new(
      "q_#{console_name}_auth_password",
      'puppet')
  end

  def console_inventory_name
    @consoles_inventory_name ||= Answer.new(
      "q_#{console_name}_inventory_certname",
      $certcmd)
  end

  def console_inventory_alt_names
    @consoles_inventory_alt_names ||= Answer.new(
      "q_#{console_name}_inventory_dnsaltnames",
      "#{$certcmd},#{$certcmd}.puppetlabs.lan,inventory_service")
  end

  def console_inventory_host
    @consoles_inventory_host ||= Answer.new(
      "q_#{console_name}_inventory_hostname",
      $certcmd)
  end

  def console_inventory_port
    @consoles_inventory_port ||= Answer.new(
      "q_#{console_name}_inventory_port",
      '8140')
  end

  def console_master
    @consoles_master ||= Answer.new(
      "q_#{console_name}_master_hostname",
      master)
  end

  def console_db_install
    @consoles_dbs_install ||= Answer.new(
      "q_#{console_name}_database_install",
      true)
  end

  def console_db_remote
    @consoles_dbs_remote ||= Answer.new(
      "q_#{console_name}_database_remote",
      database != master ? true : false)
  end

  def console_db_setup
    @consoles_dbs_setup ||= Answer.new(
      "q_#{console_name}_setup_db",
      true)
  end

  def console_db_host
    @consoles_dbs_host ||= Answer.new(
      "q_#{console_name}_database_host",
      database == host ? 'localhost' : database)
  end

  def console_db_port
    @consoles_dbs_port ||= Answer.new(
      "q_#{console_name}_database_port",
      '3306')
  end

  def console_db_root_pass
    @consoles_dbs_root_pass ||= Answer.new(
      "q_#{console_name}_database_root_password",
      'puppet')
  end

  def console_db_name
    @consoles_dbs_name ||= Answer.new(
      "q_#{console_name}_database_name",
      'console')
  end

  def console_db_user
    @consoles_dbs_user ||= Answer.new(
      "q_#{console_name}_database_user",
      'console')
  end

  def console_db_user_pass
    @consoles_dbs_users_pass ||= Answer.new(
      "q_#{console_name}_database_password",
      'puppet')
  end
end

module MasterAnswers
  def master_install
    @master_install ||= Answer.new('q_puppetmaster_install', true)
  end

  def master_name
    @masters_name ||= Answer.new('q_puppetmaster_certname', $certcmd)
  end

  def master_alt_names
    @masters_alt_names ||= Answer.new(
      'q_puppetmaster_dnsaltnames',
      "#{$certcmd},#{$certcmd}.puppetlabs.lan,puppetmaster")
  end

  def master_console_host
    @masters_console_host ||= Answer.new('q_puppetmaster_enterpriseconsole_http_port', dashboard)
  end

  def master_console_port
    @masters_console_port ||= dashboard['answers']['console_port']
  end
end

module UpgradeAnswers
  def upgrade
    @upgrade ||= Answer.new('q_upgrade_installation', true)
  end

  def remove_mco_home
    @remove_mco_home ||= Answer.new(
      'q_upgrade_remove_mco_homedir', false)
  end

  def wrapper_module_install
    @wrapper_module_install ||= Answer.new(
      'q_upgrade_install_wrapper_modules', true)
  end
end

module UninstallAnswers
  def uninstall
    @uninstall ||= Answer.new('q_pe_uninstall', true)
  end

  def purge
    @purge ||= Answer.new('q_pe_purge', false)
  end

  def remove_db
    @remove_db ||= Answer.new('q_pe_remove_db', false)
  end

  def db_root_pass
    @db_root_pass ||= Answer.new(
      'q_pe_db_root_pass',
      dashboard['answers']['console_db_root_pass'])
  end
end


