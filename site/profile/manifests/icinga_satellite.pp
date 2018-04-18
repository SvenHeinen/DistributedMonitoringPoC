class profile::icinga_satellite {

  class { '::icinga2':
    confd     => false,
    features  => ['checker','mainlog'],
    constants => {
      'ZoneName' => 'satellite',
    },
  }

  class { '::icinga2::feature::api':
    accept_commands => true,
    accept_config => true,
    endpoints       => {
      'icingaslave'    => {},
      'puppet'  => {
        'host'  => '10.0.2.5',
      }
    },
    zones           => {
      'master' => {
        'endpoints' => ['puppet'],
      }
      'satellite' => {
        'endpoints' => ['icingaslave'],
        'parent'    => 'master'
      }
    }
  }
}
