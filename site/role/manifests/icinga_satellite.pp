class role::icinga_satellite {

  #the base profile should include component modules that will be on all nodes
  include profile::base
  include profile::icinga_satellite
}
