# @summary
# Configure a restic service
#
# @api private
define restic::service (
  $commands,
  $config,
  $configs,
  $enable,
  $group,
  $user,
  $timer,
  $success_exit_status = undef,
) {
  assert_private()

  # Keep the module's current design:
  # - Build the real unit file via concat in the vendor unit directory
  # - Then create a symlink in /etc/systemd/system via systemd::unit_file
  #
  # Upstream hardcodes /lib/systemd/system. :contentReference[oaicite:4]{index=4}
  # On EL9 (RHEL/Alma/Rocky), vendor units live in /usr/lib/systemd/system.
  $unit_dir = $facts['os']['family'] ? {
    'RedHat' => '/usr/lib/systemd/system',
    default  => '/lib/systemd/system',
  }

  $unit_file = "${unit_dir}/${title}.service"

  if $enable {
    $configs.each |$key,$data| {
      concat::fragment { "restic_fragment_${title}_${key}":
        content => "${key}='${data}'",
        target  => $config,
      }
    }
    $ensure = 'present'
  } else {
    $ensure = 'absent'
  }

  ##
  ## This might seem odd to you, but it's actually thought-out
  ## We use a concat resource for the unit file, because it allows people
  ## to inject pre/post scripts into the restic backup job. This is helpful
  ## if you want to e.g. trigger database backups/cleanups
  ##
  concat { $unit_file:
    ensure         => $ensure,
    ensure_newline => true,
    owner          => 'root',
    group          => 'root',
    mode           => '0444',
    show_diff      => true,
  }

  concat::fragment { "${unit_file}-base":
    content => epp("${module_name}/restic.service.epp", {
      config              => $config,
      group               => $group,
      user                => $user,
      success_exit_status => $success_exit_status,
    }),
    target  => $unit_file,
  }

  $commands_template = @(END/L)
<% $commands.each |$command| { -%>
ExecStart=<%= $command %>
<% } -%>
  | END

  concat::fragment { "${unit_file}-commands":
    content => inline_epp($commands_template),
    target  => $unit_file,
    order   => '25',
  }

  # Symlink into /etc/systemd/system (matches upstream behavior). :contentReference[oaicite:5]{index=5}
  systemd::unit_file { "${title}.service":
    ensure    => $ensure,
    target    => $unit_file,
    group     => 'root',
    mode      => '0440',
    owner     => 'root',
    path      => '/etc/systemd/system',
    show_diff => true,
  }

  $timer_ensure = $timer ? {
    String => $ensure,
    Undef  => 'absent',
  }

  $timer_enable = $timer ? {
    String => $enable,
    Undef  => false,
  }

  $timer_content = $timer ? {
    String => epp("${module_name}/restic.timer.epp", { timer => $timer, }),
    Undef  => undef,
  }

  systemd::timer { "${title}.timer":
    ensure        => $timer_ensure,
    active        => $timer_enable,
    enable        => $timer_enable,
    timer_content => $timer_content,
  }
}
