# @summary
# Define command(s) to be run after a restic command
#
# @api public
define restic::repository::post_command (
  Variant[Array[String[1]],String[1]] $command,
  String[1]                           $repository_title = $title,
  Enum['backup', 'forget', 'restore'] $restic_command  = 'backup',
  Boolean                             $allow_fail      = false,
  Integer[26]                         $order           = 26,
) {
  $service_title = "restic_${restic_command}_${repository_title}"
  $command_md5   = md5(String($command))

  $unit_dir = $facts['os']['family'] ? {
    'RedHat' => '/usr/lib/systemd/system',
    default  => '/lib/systemd/system',
  }
  $unit_file = "${unit_dir}/${service_title}.service"

  $_allow_fail = $allow_fail ? {
    true  => '-',
    false => '',
  }

  $_command = [ $command, ].flatten.map |$c| { "ExecStartPost=${_allow_fail}${c}" }

  concat::fragment { "${unit_file}-post_commands-${command_md5}":
    target  => $unit_file,
    content => $_command.join("\n"),
    order   => String($order),
  }
}
