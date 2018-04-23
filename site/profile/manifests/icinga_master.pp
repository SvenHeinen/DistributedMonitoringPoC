class profile::icinga_master {
  class { 'apache':
    mpm_module => 'prefork'
  }

  class { 'apache::mod::php': }

  case $::osfamily {
    'redhat': {
      package { 'php-mysql': }

      file {'/etc/httpd/conf.d/icingaweb2.conf':
        source  => 'puppet:///modules/icingaweb2/examples/apache2/icingaweb2.conf',
        require => Class['apache'],
        notify  => Service['httpd'],
      }
    }
    'debian': {
      class { 'apache::mod::rewrite': }

      file {'/etc/apache2/conf.d/icingaweb2.conf':
        source  => 'puppet:///modules/icingaweb2/examples/apache2/icingaweb2.conf',
        require => Class['apache'],
        notify  => Service['apache2'],
      }
    }
    default: {
      fail("Your plattform ${::osfamily} is not supported by this example.")
    }
  }

  include ::mysql::server

  mysql::db { 'icingaweb2':
    user     => 'icingaweb2',
    password => 'icingaweb2',
    host     => 'localhost',
    grant    => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'INDEX', 'EXECUTE', 'ALTER', 'REFERENCES'],
  }
  
  mysql::db { 'icinga2':
    user     => 'icinga2',
    password => 'supersecret',
    host     => 'localhost',
    grant    => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'INDEX', 'EXECUTE', 'ALTER'],
  }

  class {'icingaweb2':
    manage_repo   => true,
    import_schema => true,
    db_type       => 'mysql',
    db_host       => 'localhost',
    db_port       => 3306,
    db_name       => 'icingaweb2',
    db_username   => 'icingaweb2',
    db_password   => 'icingaweb2',
    require       => Mysql::Db['icingaweb2'],
  }

  class {'icingaweb2::module::monitoring':
    ido_host          => 'localhost',
    ido_db_name       => 'icinga2',
    ido_db_username   => 'icinga2',
    ido_db_password   => 'supersecret',
    commandtransports => {
      icinga2 => {
        transport => 'api',
        username  => 'root',
        password  => 'icinga',
      }
    }
  }

  icingaweb2::config::resource{'icingaweb2-module-director':
    type        => 'db',
    db_type     => 'mysql',
    host        => 'localhost',
    port        => 3306,
    db_name     => 'director',
    db_username => 'director',
    db_password => 'some-password',
    db_charset  => "utf8"
  }
  
  class { 'icinga2':
#    manage_repo    => true,
    purge_features => false,
    confd          => false,
    features       => ['checker','mainlog','notification','statusdata','compatlog','command'],
    constants      => {
      'ZoneName' => 'master',
    }
  }

  class{ '::icinga2::feature::idomysql':
    user          => 'icinga2',
    password      => 'supersecret',
    database      => 'icinga2',
    import_schema => true,
    require       => Mysql::Db['icinga2'],
  }

  class { '::icinga2::feature::api':
    accept_commands => true,
    accept_config   => true,
    zones           => {
      'ZoneName' => {
        'endpoints' => [ 'NodeName' ],
      }
    },
    endpoints       => {
      'NodeName'  => {},
    }
  }

  icinga2::object::zone { ['global-templates', 'windows-commands', 'linux-commands']:
    global => true,
    order  => '47',
  }

  file { ['/etc/icinga2/zones.d/master',
    '/etc/icinga2/zones.d/windows-commands',
    '/etc/icinga2/zones.d/linux-commands',
    '/etc/icinga2/zones.d/global-templates']:
    ensure => directory,
    owner  => 'icinga',
    group  => 'icinga',
    mode   => '0750',
    tag    => 'icinga2::config::file',
  }

  File <<| tag == "icinga2::slave::zone" |>>

  # Static Icinga 2 objects
  ::icinga2::object::service { 'ping4':
    import        => ['generic-service'],
    apply         => true,
    check_command => 'ping',
    assign        => ['host.address'],
    target        => '/etc/icinga2/zones.d/global-templates/services.conf',
  }

  ::icinga2::object::service { 'cluster zone':
    import        => ['generic-service'],
    apply         => true,
    check_command => 'cluster-zone',
    assign        => ['host.vars.os == Linux || host.vars.os == Windows'],
    ignore        => ['host.vars.noagent'],
    target        => '/etc/icinga2/zones.d/global-templates/services.conf',
  }

  ::icinga2::object::service { 'linux_load':
    import           => ['generic-service'],
    service_name     => 'load',
    apply            => true,
    check_command    => 'load',
    command_endpoint => 'host.name',
    assign           => ['host.vars.os == Linux'],
    ignore           => ['host.vars.noagent'],
    target           => '/etc/icinga2/zones.d/global-templates/services.conf',
  }

  ::icinga2::object::service { 'linux_disks':
    import           => ['generic-service'],
    apply            => 'disk_name => config in host.vars.disks',
    check_command    => 'disk',
    command_endpoint => 'host.name',
    vars             => 'vars + config',
    assign           => ['host.vars.os == Linux'],
    ignore           => ['host.vars.noagent'],
    target           => '/etc/icinga2/zones.d/global-templates/services.conf',
  }

  # Collect objects
  ::Icinga2::Object::Endpoint <<| |>>
  ::Icinga2::Object::Zone <<| |>>
  ::Icinga2::Object::Host <<| |>>

  # Static config files
  file { '/etc/icinga2/zones.d/global-templates/templates.conf':
    ensure => present,
    owner  => 'icinga',
    group  => 'icinga',
    mode   => '0640',
    source => 'puppet:///modules/profile/templates.conf'
}
}
