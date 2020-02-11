# OpenStudio Extension Gem

## Version 0.1.5 (Unreleased)

## Version 0.1.4

* Update license copyright dates
* Update template for Gemfile to include FAVOR_LOCAL_GEMS env variable
 
## Version 0.1.3

* Move runner configuration options to runner initializer. Allow user to set the number of parallel simulations, max number of simulations, run the simulations (true/false), and verbose output.
* Add a runner.conf file that can be used to define how the run_osw(s) behaves.
* Add rake task to initialize the runner.conf (e.g., rake openstudio:runner:init)

## Version 0.1.2

* Support for BuildingSync gem
* Add run_osws capability

## Version 0.1.1

* Initial release