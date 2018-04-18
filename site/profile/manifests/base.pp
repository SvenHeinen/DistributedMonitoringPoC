class profile::base {

  #the base profile should include component modules that will be on all nodes
  include epel
  package {'nagios-plugins-all':}
}
