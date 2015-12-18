# == Class: cassandra
#
# Please see the README for this module for full details of what this class
# does as part of the module and how to use it.
#
class cassandra (
  $authenticator                         = 'AllowAllAuthenticator',
  $authorizer                            = 'AllowAllAuthorizer',
  $auto_snapshot                         = true,
  $cassandra_package_ensure              = 'present',
  $cassandra_package_name                = 'dsc21',
  $cassandra_yaml_tmpl                   = 'cassandra/cassandra.yaml.erb',
  $client_encryption_enabled             = false,
  $client_encryption_keystore            = 'conf/.keystore',
  $client_encryption_keystore_password   = 'cassandra',
  $client_cipher_suites                  = ['TLS_RSA_WITH_AES_256_CBC_SHA'],
  $cluster_name                          = 'Test Cluster',
  $commitlog_directory                   = '/var/lib/cassandra/commitlog',
  $concurrent_counter_writes             = 32,
  $concurrent_reads                      = 32,
  $concurrent_writes                     = 32,
  $config_path                           = undef,
  $data_file_directories                 = ['/var/lib/cassandra/data'],
  $disk_failure_policy                   = 'stop',
  $endpoint_snitch                       = 'SimpleSnitch',
  $hinted_handoff_enabled                = true,
  $incremental_backups                   = false,
  $internode_compression                 = 'all',
  $listen_address                        = 'localhost',
  $manage_dsc_repo                       = false,
  $native_transport_port                 = 9042,
  $num_tokens                            = 256,
  $partitioner
    = 'org.apache.cassandra.dht.Murmur3Partitioner',
  $rpc_address                           = 'localhost',
  $rpc_port                              = 9160,
  $rpc_server_type                       = 'sync',
  $saved_caches_directory                = '/var/lib/cassandra/saved_caches',
  $seeds                                 = '127.0.0.1',
  $server_encryption_internode           = 'none',
  $server_encryption_keystore            = 'conf/.keystore',
  $server_encryption_keystore_password   = 'cassandra',
  $server_encryption_truststore          = 'conf/.truststore',
  $server_encryption_truststore_password = 'cassandra',
  $server_cipher_suites                  = ['TLS_RSA_WITH_AES_256_CBC_SHA'],
  $service_enable                        = true,
  $service_ensure                        = 'running',
  $service_name                          = 'cassandra',
  $snapshot_before_compaction            = false,
  $start_native_transport                = true,
  $start_rpc                             = true,
  $storage_port                          = 7000,
  $systemd                               = false
  ) {
  case $::osfamily {
    'RedHat': {
      if $config_path == undef {
        $cfg_path = '/etc/cassandra/default.conf'
      } else {
        $cfg_path = $config_path
      }

      if ( $systemd ) {
        file { "/usr/lib/systemd/system/cassandra.service":
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          source  => 'puppet:///modules/cassandra/cassandra.service',
          before  => Service['cassandra'];

        "/etc/rc.d/init.d/cassandra":
          ensure  => absent,
          before  => Service['cassandra'],
          require => Package[ $cassandra_package_name ];

        }

      }

      if $manage_dsc_repo == true {
        yumrepo { 'datastax':
          ensure   => present,
          descr    => 'DataStax Repo for Apache Cassandra',
          baseurl  => 'http://rpm.datastax.com/community',
          enabled  => 1,
          gpgcheck => 0,
          before   => Package[ $cassandra_package_name ],
        }
      }
    }
    'Debian': {
      if $config_path == undef {
        $cfg_path = '/etc/cassandra'
      } else {
        $cfg_path = $config_path
      }

      if $manage_dsc_repo == true {
        include apt
        include apt::update

        apt::key {'datastaxkey':
          id     => '7E41C00F85BFC1706C4FFFB3350200F2B999A372',
          source => 'http://debian.datastax.com/debian/repo_key',
          before => Apt::Source['datastax']
        }

        apt::source {'datastax':
          location => 'http://debian.datastax.com/community',
          comment  => 'DataStax Repo for Apache Cassandra',
          release  => 'stable',
          include  => {
            'src' => false
          },
          notify   => Exec['update-cassandra-repos']
        }

        # Required to wrap apt_update
        exec {'update-cassandra-repos':
          refreshonly => true,
          command     => '/bin/true',
          require     => Exec['apt_update'],
          before      => Package[ $cassandra_package_name ]
        }
      }
    }
    default: {
      fail("OS family ${::osfamily} not supported")
    }
  }

  package { $cassandra_package_name:
    ensure => $cassandra_package_ensure,
  }

  if $config_path != undef {
    $cfg_path = $config_path
  }

  $config_file = "${cfg_path}/cassandra.yaml"

  file { $config_file:
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    content => template($cassandra_yaml_tmpl),
    require => Package[$cassandra_package_name],
    notify  => Service['cassandra'],
  }

  if $cassandra_package_ensure != 'absent'
  and $cassandra_package_ensure != 'purged' {
    service { 'cassandra':
      ensure  => running,
      name    => $service_name,
      enable  => true,
      require => Package[$cassandra_package_name],
    }
  }
}
