# OpenStudio::Extension 

This gem repository serves as a base for single purpose repositories that host API methods, CLI tools, and OpenStudio measures which leverage those methods and tools.  Other repositories (e.g. urbanopt-geojson-gem) will depend on this repository and inherit/mix-in needed functionality.  The repository is formatted as a gem to allow for semantic versioning via Bundle.  The repository includes methods for testing, documentation, and build tasks.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-extension'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'openstudio-extension'

## Usage

The ```openstudio-extension``` gem is meant to be used as a base for creating new gems to use with OpenStudio.  The intention is to standardize best practices and common patterns in one location rather than try to synchronize them across many independent gems.  Existing gems such as ```openstudio-standards``` and ```openstudio-workflow``` may be refactored to depend on ```openstudio-extension``` in the future.  The immediate use of ```openstudio-extension``` will be for new gems.  New gems that may be considered a part of OpenStudio and potentially distributed with OpenStudio in the future should be named as ```openstudio-#{gem-name}```, e.g. ```openstudio-model-articulation``` is a gem to implement model articulation methods for OpenStudio.  Other gems that extend OpenStudio for specific applications or other domains should be named separately, e.g. ```buildingsync``` is an extension of OpenStudio specifically for use with BuildingSync files.  _DLM: should we specify naming conventions for gem repos?  E.g. OpenStudio should be camel or snake case, repo should end with ```-gem``` but gem name should not?_  Each OpenStudio extension gem should define its own module name to ensure that there are no code collisions with other extension gems. If the gem name is prefixed with ```openstudio-``` then the module name can be nested under the OpenStudio module.

| openstudio-model-articulation                                                                               	| buildingsync                                                                	|
|-------------------------------------------------------------------------------------------------------------	|-----------------------------------------------------------------------------	|
| module OpenStudio   module ModelArticulation     class ModelArticulation < OpenStudio::Extension::Extension 	| module BuildingSync   class BuildingSync < OpenStudio::Extension::Extension 	|

_DLM: I am not crazy about having both a module name and class name for each extension gem.  I think module names are nice to separate code, the class name seems a bit forced.  But classes are easier to extend whereas modules can be mixed in but harder to redefine/extend functionality in the base module._

Your gem should list its gem dependencies (including ```openstudio-extension```) in its gemspec file.  This is what is used to determine dependencies for consumers of your gem.  You should only list actual dependencies of your gem in the gemspec.  You can list specific sources for your gems (e.g. on github, local file) in your Gemfile.  If you are writing an application rather than a gem, you can only have a Gemfile, you do not need a gemspec unless you are releasing your code as a gem.

OpenStudio Measures related to your gem should be placed in ```lib/measures```.

Once you have included ```openstudio-extension``` as a dependency of your gem, you can inherit common rake tasks into your application's Rakefile.

```
require 'openstudio/extension/rake_task'
OpenStudio::Extension::RakeTask.new
```

From the command line, run these with ```bundle exec rake #{task_name}```
* ```openstudio:update_measures``` - Update xml files for OpenStudio Measures in your gem
* ```openstudio:test_with_openstudio``` - Run all tests for OpenStudio Measures in your gem

## TODO

- [ ] Finalize documentation on naming conventions, etc
- [X] Add test measure
- [X] Rake task ```openstudio:update_measures```
- [X] Rake task ```openstudio:test_with_openstudio```
- [ ] Rake task ```stage_bcl``` _DLM: BCL gem should be a development dependency only until we can reduce its dependencies and remove native dependencies? should probably put it into a special group so we can bundle without it in openstudio-gems._
- [ ] Rake task ```push_bcl``` _DLM: how do we want to test this?
- [X] Get all rake tasks working on Travis
- [ ] Capture useful output from Travis (measure dashboard results, log files, zip of build products, etc) and put it somewhere (s3?  naming convention?)
- [X] ```Extension::openstudio_extension_version``` _DLM: should we rename? should people overwrite this in their class?_
- [X] ```Extension::measures_dir``` _DLM: I think this can have a default implementation, right? If something does not need to be overridden should it be a module method rather than a class one?  KAF: this is in rake task for now
- [X] ```Extension::list_measures``` _DLM: I think this can have a default implementation, right?_KAF: In Rake task for now
- [ ] ```Extension::files_dir``` _DLM: I think this can have a default implementation, right?_
- [ ] ```Extension::minimum_openstudio_version``` _DLM: should we rename? should people overwrite this in their class?_
- [X] ```Runner::initialize``` _DLM: should say that the path argument should be for a dir with a Gemfile right?_
- [X] ```Runner::configure_osw``` _DLM: should take in an OSW, add paths to all measure and file dirs for loaded OpenStudio Extensions, write out configured OSW_
- [ ] Run rubocop on all of the core files and remove exclusion from .rubocop.yml file.
- [ ] Cleanup task after running tests (may need to be in the OpenStudio Measure Tester)
- [ ] Add a `rake init new_ext_gem` to Rakefile
- [ ] Add tests to the extension/core

# Releasing

* Update change log
* Update version in `/lib/openstudio/extension/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master  