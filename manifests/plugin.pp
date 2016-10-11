#
# == Define kibana::plugin
#
#  Defined type to manage kibana plugins
#
define kibana::plugin(
  $source                 = undef,
  $ensure                 = 'present',
  $install_root           = $::kibana::install_path,
  $group                  = $::kibana::group,
  $user                   = $::kibana::user,
  $offline_plugin_install = $::kibana::offline_plugin_install,
  $tmp_dir                = $::kibana::tmp_dir,
  $plugin_file            = $::kibana::plugin_file) {

  validate_bool($offline_plugin_install)
  validate_absolute_path($tmp_dir)

  if $offline_plugin_install == true {
    if !$plugin_file {
      fail("Class['kibana::plugin']: you must specify a value for plugin_file.")
    }
    $install_file = "${tmp_dir}/${name}.tar.gz"
    $install_cmd = "kibana plugin --install ${name} --url file:///${install_file}"
  }
  else {
    # plugins must be formatted <org>/<plugin>/<version>
    $filenameArray = split($source, '/')
    $base_module_name = $filenameArray[-2]
    $install_cmd = "kibana plugin --install ${source}"
  }

  # borrowed heavily from https://github.com/elastic/puppet-elasticsearch/blob/master/manifests/plugin.pp
  $plugins_dir = "${install_root}/kibana/installedPlugins"
  $uninstall_cmd = "kibana plugin --remove ${name}"

  Exec {
    path      => [ '/bin', '/usr/bin', '/usr/sbin', "${install_root}/kibana/bin" ],
    cwd       => '/',
    user      => $user,
    tries     => 6,
    try_sleep => 10,
    timeout   => 600,
  }
  
  case $ensure {
    'installed', 'present': {
      $name_file_path = "${plugins_dir}/${name}/.name"
      if $offline_plugin_install == true {
        exec { "download_plugin_$name":
          path    => [ '/bin', '/usr/bin', '/usr/local/bin' ],
          command => "${::kibana::params::download_tool} $install_file $plugin_file 2> /dev/null",
          require => User[$user],
          unless  => "test -e ${install_file}",
        }
        exec { "install_plugin_${name}":
          command => $install_cmd,
          creates => $name_file_path,
          notify  => Service['kibana'],
          require => [File[$plugins_dir],Exec["download_plugin_$name"]],
        }
        file {$name_file_path:
          ensure  => file,
          content => $base_module_name,
          require => Exec["install_plugin_${name}"],
        }
      }
      else {
        exec {"install_plugin_${name}":
          command => $install_cmd,
          creates => $name_file_path,
          notify  => Service['kibana'],
          require => File[$plugins_dir],
        }
        file {$name_file_path:
          ensure  => file,
          content => $base_module_name,
          require => Exec["install_plugin_${base_module_name}"],
        }
      }
    }
    'absent': {
      exec {"remove_plugin_${name}":
        command => $uninstall_cmd,
        onlyif  => "test -f ${name_file_path}",
        notify  => Service['kibana'],
      }
    }
    default: {
      fail("${ensure} is not a valid ensure command.")
    }
  }
}
