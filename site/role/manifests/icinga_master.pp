class role::icinga_master {

  #the base profile should include component modules that will be on all nodes
  include profile::base
  include profile::icinga_master
}
