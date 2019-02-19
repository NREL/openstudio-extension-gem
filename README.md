# OpenStudio Extension Gem

This gem repository serves as a base for single purpose repositories that host API methods, CLI tools, and OpenStudio measures which leverage those methods and tools.  Other derivative extension gem repositories will depend on this repository and inherit/mix-in needed functionality.  The repository is formatted as a gem to allow for semantic versioning via Bundle.  The repository includes methods for testing, documentation, and build tasks.

## Overview

The OpenStudio Extension Gem contains methods and patterns to extend OpenStudio.  It is a template that can be used to create other extension gems.  

Derivative extension gems should include this gem to access common functionality, such as:
* OpenStudio CLI functionality such as list_measures and update_measures
* adding documentation and license files to measures
* adding core resource files to measures
* pushing measures to BCL

Extension gems will contain a small group of related measures. Each extension gem will be the unique location to find these measures, and will be responsible for
testing and maintaining the measures as well as pushing them to BCL. 

## Usage

The ```openstudio-extension``` gem is meant to be used as a base for creating new gems to use with OpenStudio.  The intention is to standardize best practices and common patterns in one location rather than try to synchronize them across many independent gems.  

Existing gems such as ```openstudio-standards``` and ```openstudio-workflow``` may be refactored to depend on ```openstudio-extension``` in the future.  The immediate use of ```openstudio-extension``` will be for new gems.  New gems that may be considered a part of OpenStudio and potentially distributed with OpenStudio in the future should be named as ```openstudio-#{gem-name}```, e.g. ```openstudio-model-articulation``` is a gem to implement model articulation methods for OpenStudio.  
Other gems that extend OpenStudio for specific applications or other domains should be named separately, e.g. ```buildingsync``` is an extension of OpenStudio specifically for use with BuildingSync files.

Each OpenStudio extension gem should define its own module name to ensure that there are no code collisions with other extension gems. If the gem name is prefixed with ```openstudio-``` then the module name can be nested under the OpenStudio module.

| openstudio-model-articulation                                                                               	| buildingsync                                                                	|
|-------------------------------------------------------------------------------------------------------------	|-----------------------------------------------------------------------------	|
| module OpenStudio   module ModelArticulation     class ModelArticulation < OpenStudio::Extension::Extension 	| module BuildingSync   class BuildingSync < OpenStudio::Extension::Extension 	|


## Installation

To use this and other extension gems, you will need Ruby 2.2.4 and OpenStudio 2.7.1 or greater.  

### Windows Installation
Install Ruby using the [RubyInstaller](https://rubyinstaller.org/downloads/archives/) for [Ruby 2.2.4 (x64)](https://dl.bintray.com/oneclick/rubyinstaller/rubyinstaller-2.2.4-x64.exe).

Install Dekit using the [mingw64](https://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe) installer.

Check the ruby installation returns the correct Ruby version (2.2.4):
```
ruby -v
```

Install bundler from the command line
```
gem install bundler
```

Install OpenStudio.  Create a file ```C:\ruby-2.2.4-x64-mingw32\lib\ruby\site_ruby\openstudio.rb``` and point it to your OpenStudio installation by editing the contents.  E.g.:

```ruby
require 'C:\openstudio-2.7.1\Ruby\openstudio.rb'
```

Verify your OpenStudio and Ruby configuration:
```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

### Mac Installation
It is recommended that you install [rbenv](https://github.com/rbenv/rbenv) to easily manage difference versions of Ruby.
rbenv can be installed view Homebrew:
```ruby
brew install rbenv
rbenv init
rbenv install 2.2.4
```

Also install bundler
```ruby
gem install bundler
```

## Contents
The OpenStudio Extension Gem (this repo) contains methods that can be shared across and extended by other derivative extension gems.

### Directory Structure

Extension gem and the derivative extension gem should have the following directory structure:

├── doc_templates
├── init_templates
├── lib
│       ├── data
│       ├── files
│       ├── measures
│       └── openstudio
│                         └── extension
│                                       └── core
└── spec
                       ├── files
                       └── openstudio
                                    └── core
`doc_templates` contains copyright and license file templates that can be copied and added to each measure.  
The derivative extension gems should have their own doc_templates directory.

`init_templates` are used with the `init-new-gem` rake task to create a derivative extension gem directory structure.

`lib` contains data
* `data` contains custom data for the gem
* `files` contains files referenced by measures or workflows
* `measures` contains the measures included in the gem.  
* `openstudio` and `openstudio\extension` contain the code related to this gem.
* `openstudio\extension\core` contains core resource files shared across a variety of measures.  

Your gem should list its gem dependencies (including ```openstudio-extension```) in its gemspec file.  This is what is used to determine dependencies for consumers of your gem.  
You should only list actual dependencies of your gem in the gemspec.  You can list specific sources for your gems (e.g. on github, local file) in your Gemfile.  If you are writing an application rather than a gem, you can only have a Gemfile. You do not need a gemspec unless you are releasing your code as a gem.
Once you have included ```openstudio-extension``` as a dependency of your gem, you can inherit common rake tasks into your application's Rakefile.

### Core Library
The `core` folder located at `lib\openstudio\extension` contains core resource files shared across a variety of measures.  The files should be edited in the OpenStudio-extension-gem, and the rake task (`bundle exec rake openstudio:measures:copy_resources`) should be used to update the measures that depend on them.
Note that this folder is for 'core' functionality; if a measure's requires a new one-off function, this should be developed in place, within the measure's `resources` folder.

Having a single repository for all measures, such as the OpenStudio-measures repo, can be cumbersome to test and keep up to date. 
In this new framework, each extension gem will contain one or more related measures.  The gem will be the new 'home' of these measures, and the repo owner will be responsible for testing and keeping the measures up to date.

In the short term, in order to preserve the PAT/OS App functionality, resource files will still be copied directly into the measures, and these measures will be pushed to BCL.

### Rake Tasks
Common Rake Tasks that are available to derivative extension gems include:
| Rake Task | Description |
| --------- | ----------- |
| openstudio:list_measures             | List all measures in the calling gem |
| openstudio:measures:add_license      | Add License File to measures in the calling gem |
| openstudio:measures:add_readme       | Add README.md.erb file if it and the README markdown file do not already exist for a measure |
| openstudio:measures:copy_resources   | Copy the resources files to individual measures in the calling gem |
| openstudio:measures:update_copyright | Update copyright on measure files in the calling gem |
| openstudio:stage_bcl                 | Copy the measures to a location that can be uploaded to BCL |
| openstudio:push_bcl                  | Upload measures from the specified location to the BCL |
| openstudio:test_with_docker          | Use openstudio docker image to run tests |
| openstudio:test_with_openstudio      | Use openstudio system ruby to run tests |
| openstudio:update_measures           | Run the CLI task to check for measure updates and update the measure xml files |

These can all be invoked from the derivative gem by running the following command in a terminal:

``` bundle exec rake <name_of_rake_task>```

To list all available rake tasks:

``` bundle exec rake -T ```

## Derivative Extension Gems

The following table contains all current extension gems.

| Name   |   Gem Name | Repo | 
| ------ | ---------- | ------ |
| OpenStudio Extension Gem | openstudio-extension | https://github.com/NREL/OpenStudio-extension-gem | 
| OpenStudio Common Measures Gem  | openstudio-common-measures | https://github.com/NREL/openstudio-common-measures-gem |
| OpenStudio Model Articulation Gem   | openstudio-model-articulation | https://github.com/NREL/openstudio-model-articulation-gem |
| OpenStudio AEDG Gem | openstudio-aedg | https://github.com/NREL/openstudio-aedg-gem | 
| OpenStudio District Systems Gem | openstudio-district-systems | https://github.com/NREL/openstudio-district-systems-gem | 
| UrbanOpt GeoJSON Gem | urbanopt-geojson | https://github.com/urbanopt/urbanopt-geojson-gem | 
| BuildingSync Gem | buildingsync | https://github.com/BuildingSync/BuildingSync-gem | 

### Initializing a new Extension Gem
The OpenStudio-extension gem can be used to easily initialize a new derivative extension gem.  

* First, call the rake task:
    ```ruby
    bundle exec rake init-new-gem
    ```
    * Enter the name of the gem repository (use dashes between words and the repo name should end with '-gem')
    * Enter the location of the directory where the gem directory should be created
    The rake task will create the gem directory and stub out the required files.
    
* You can then obtain a github repository and commit the newly created gem directory to it

### Coding Conventions
* Name your extension gem repo:  OpenStudio-<gem name in lowercase>-gem.  Use dashes between words. Example:  OpenStudio-extension-gem
* Name the actual gem: openstudio-<gem name in lowercase>. 'openstudio' should be lowercase. Use dashes between words.  Example: openstudio-extension
* Use lowercase snake_case for methods and variables.
* Use CamelCase for classes and modules. (Keep acronyms like HTTP, RFC, XML uppercase.)
* All files and classes should have underscores (no dashes) and (lowercase snake_case)
* Dashes should be used in module names

### Pushing to BCL
Use the rake tasks listed above to stage and push measures to BCL.  
**Note of warning**: Use caution when pushing to the BCL.  Public and private measures could be pushed to BCL from within an extension gem, even though the extension gem repo may be private.

TODO: Add warning to rake task and lists what gems will be pushed 
TODO: Check that license files, etc. are present in each measure before pushing to BCL

## Include in a project

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-extension'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'openstudio-extension'

# Releasing the gem

* Update change log
* Update version in `/lib/openstudio/extension/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master  

# TODO

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
