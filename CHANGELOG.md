# OpenStudio Extension Gem

## Version 0.2.2

* Exclude measure tests from being released with the gem (reduces the size of the installed gem significantly)
* Add BCL commands to upload measures
* Update GitHub changelog gem to use Octokit compared to github_api (which was last released 3 years ago)
* Promote GitHub changelog creation to a rake task to be inherited by all downstream extension gems

## Version 0.2.1

* Changes from 0.1.5 (runner.conf bug)
* Changes from 0.1.6 (update core library)
* Update measure tester to 0.2.2 (with Rubocop 0.54)

## Version 0.2.0

* Upgrade Bundler to 2.1.x
* Restrict to Ruby ~> 2.5.0
* Remove json_pure gem
* Update measure tester to 0.2.0 (removes need for github checkout)
* Note that this version does not include the changes from Version 0.1.5

## Version 0.1.6

* Update core library methods with what was in OpenStudio-measures

## Version 0.1.5

* Fix bug to respect the runner.conf file when using Extension::Runner with no options

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
