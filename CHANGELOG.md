# OpenStudio(R) Extension Gem
## Version 0.9.2
* Updating LICENSE.md in doc_templates to use 2025 for the year

## Version 0.9.1
* Updating faraday to 1.10.4 to remove deprecation notice

## Version 0.9.0
* Updating dependencies for OpenStudio 3.10

## Version 0.8.3
* [#199]( https://github.com/NREL/openstudio-extension-gem/pull/199), Patch for bundler conflict issue

## Version 0.8.2

* [#192]( https://github.com/NREL/openstudio-extension-gem/pull/192), Pinned regexp_parser version

## Version 0.8.1

* [#190]( https://github.com/NREL/openstudio-extension-gem/pull/190), Don't raise error when bundle path mismatch occurs

## Version 0.8.0

* [#184]( https://github.com/NREL/openstudio-extension-gem/pull/184 ), Removing model methods and model method spec tests. Most model methods moved to openstudio-standards-gem, others moved to OpenStudio C++.

* Update dependencies to support Ruby 3.2.2 / OpenStudio 3.8.0

## Version 0.7.1

* Fixed [#169]( https://github.com/NREL/openstudio-extension-gem/pull/169 ), Replace --verbose flag to --loglevel inorder to run CI.
* Fixed [#171]( https://github.com/NREL/openstudio-extension-gem/pull/171 ), Remove bundle flag
* Fixed [#172]( https://github.com/NREL/openstudio-extension-gem/pull/172 ), useless commit, to trigger the CI
* Fixed [#173]( https://github.com/NREL/openstudio-extension-gem/pull/173 ), Remove bundle flag to run in ci with new commit.
* Fixed [#174]( https://github.com/NREL/openstudio-extension-gem/pull/174 ), Bump os-standards to 0.5.0

## Version 0.7.0

* Fixed [#156]( https://github.com/NREL/openstudio-extension-gem/pull/156 ), Adding test for lab building type
* Fixed [#165]( https://github.com/NREL/openstudio-extension-gem/pull/165 ), Remove district systems gem
* Upgrade developer dependency to openstudio-standards gem to `~> 0.5.0`

## Version 0.6.1

* Updating to new licensing format and updating copyrights

## Version 0.6.0

* Fixed [#150]( https://github.com/NREL/openstudio-extension-gem/pull/150 ), Fixed Outpatient DressingRoom name
* Adding in new DOE templates `ComStock 90.1-2016` and `ComStock 90.1-2019`
* Adding in new DOE Building Types `Courthouse` and `College`
* Upgrade developer dependency to openstudio-standards gem to `~> 0.2.17`

## Version 0.5.1

* Fix adjancent surface matching 

## Version 0.5.0

* Update OpenStudio Workflow Gem to 2.3.0 (support for epJSON)
* Fixed [#133]( https://github.com/NREL/openstudio-extension-gem/pull/133 ), cleanup readme and rework BCL tasks
* Fixed [#135]( https://github.com/NREL/openstudio-extension-gem/pull/135 ), Intersect tests 072021
* Fixed [#136]( https://github.com/NREL/openstudio-extension-gem/pull/136 ), Osm from haystack
* Fixed [#137]( https://github.com/NREL/openstudio-extension-gem/issues/137 ), Edge case error in hospital bar
* Fixed [#138]( https://github.com/NREL/openstudio-extension-gem/issues/138 ), os_lib_model_generation does not assign SWH type correctly
* Fixed [#139]( https://github.com/NREL/openstudio-extension-gem/pull/139 ), fix swh_src assignment operators
* Fixed [#142]( https://github.com/NREL/openstudio-extension-gem/pull/142 ), added arg for hoo_var_method and updated test to use it

## Version 0.4.4

* Update BCL gem to version 0.7.1 which upgrades REXML and Spreadsheet with security patches
* Minor updates to documentation

## Version 0.4.3

* Update measure tester gem which upgrades Rubocop to 1.15
* Update styles to v4 based on new version of Rubocop

## Version 0.4.2

* Fixes [#113](https://github.com/NREL/openstudio-extension-gem/issues/113) Fix bad args behavior on bar_from_building_type_ratios
* Fixes [#103](https://github.com/NREL/openstudio-extension-gem/issues/103) make check_upstream_measure_for_arg more robust for non string arguments
* Updatd version of openstudio-standards for development to openstudio-standards 0.2.13
* Added ASHRAE 90.1 2016 and 2019 to get_doe_templates method in os_lib_model_generation.rb file. This method is used by a number of measures to generate allowable argument values

## Version 0.4.1

* Fixed [#95]( https://github.com/NREL/openstudio-extension-gem/issues/95 ), Extend exceptions on standards error messages for curves used on multiple objects
* Fixed [#113]( https://github.com/NREL/openstudio-extension-gem/issues/113 ), Fix bad args behavior on bar_from_building_type_ratios
* Fixed [#111]( https://github.com/NREL/openstudio-extension-gem/pull/111 ), night cycling change - for 0.4.x
* Updated version of openstudio-standards for development to openstudio-standards 0.2.13.rc3	

## Version 0.4.0

* Fix merging of options on initialization. Options hash will overwrite the default config AND the runner.conf files.
* Includes patch of 0.2.6 (failed.job and finished.job)
* Support Ruby 2.7.0, Bundler > 2.2
* Update copyrights

## Version 0.3.2

* Update Extension Gem Template
* Add gemfile path instead of just dirname to the initialization
* Update to latest workflow gem to support URBANopt Workflow

## Version 0.3.1

* This change first zeroes-out latent (for good measure) and radiant fractions before setting lost fraction to 1.0 to avoid this error.

## Version 0.3.0

* remove the os_lib_reporting.rb helpers. This file is only used for OS reporting measure and should not be shared with other users.
* Upgrade dependency to openstudio-workflow gem to `~> 2.1.0`
* This version works only with EnergyPlus 9.4 since it depends on OpenStudio workflow `~> 2.1.0`

## Version 0.2.6

- Check that `failed.job` doesn't exist and `finished.job` does exist.
- Fixed [#98](https://github.com/NREL/openstudio-extension-gem/issues/98)

## Version 0.2.5

* Support runner options for bundle_install_path and gemfile_path
* Laboratory and Data Center Support

- Fixed [#71]( https://github.com/NREL/openstudio-extension-gem/pull/71 ), another fix for bcl rake tasks
- Fixed [#72]( https://github.com/NREL/openstudio-extension-gem/pull/72 ), Add laboratory and data centers to os_lib_model_generation
- Fixed [#74]( https://github.com/NREL/openstudio-extension-gem/pull/74 ), adding bundle path and gemfile path options

## Version 0.2.4

* Fixed upload of measures to BCL using rake tasks.
* Support economizer modeling when create_typical measure is split into two parts

Closed Issues: 1
- Fixed [#64]( https://github.com/NREL/openstudio-extension-gem/issues/64 ), README updates

## Version 0.2.3

* Use new version of rubocop style from S3
* Remove frozen string literals in comments

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
