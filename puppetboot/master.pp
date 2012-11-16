node default {
    include bootpuppet
}

class bootpuppet {
  package{'ruby-stomp':
    ensure => "latest"
  }

  package{'mcollective':
    ensure => "latest",
    require => Package['ruby-stomp']
  }


}
