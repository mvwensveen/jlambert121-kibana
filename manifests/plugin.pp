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
  $user                   = $::kibana::user) {

  $plugins_dir = "${install_root}/kibana/installedPlugins"

  validate_string($source)
  $org_package_version = split($source, '/')
  if $source =~ /^(https?|file):\/\/.*$/ and $name {
    $plugin_name = $title
    $install_cmd = "kibana plugin --install ${plugin_name} --url ${source}"
  }
  elsif is_array($org_package_version) and size($org_package_version) == 3 {
    $plugin_name = $org_package_version[-2]
    $install_cmd = "kibana plugin --install ${source}"
  }
  else
  {
    fail("Kibana::plugin source is not valid. Must be <org>/<package>/<version> or direct http/https or file uri")
  }
  
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
      $name_file_path = "${plugins_dir}/${plugin_name}/.name"
      exec {"install_plugin_${plugin_name}":
        command => $install_cmd,
        creates => $name_file_path,
        notify  => Service['kibana'],
        require => File[$plugins_dir],
      }
      file {$name_file_path:
        ensure  => file,
        content => $plugin_name,
        require => Exec["install_plugin_${plugin_name}"],
      }
    }
    'absent': {
      exec {"remove_plugin_${plugin_name}":
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