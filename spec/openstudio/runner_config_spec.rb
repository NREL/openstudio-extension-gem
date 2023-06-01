# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'json'
RSpec.describe OpenStudio::Extension::RunnerConfig do
  before :all do
    if File.exist? 'runner.conf'
      puts 'removing runner conf'
      File.delete('runner.conf')
    end
  end

  it 'has defaults' do
    defaults = OpenStudio::Extension::RunnerConfig.default_config
    expect(defaults[:max_datapoints]).to eq 1E9.to_i
    expect(defaults[:num_parallel]).to eq 2
    expect(defaults[:run_simulations]).to eq true
    expect(defaults[:verbose]).to eq false
    expect(defaults[:gemfile_path]).to eq ''
    expect(defaults[:bundle_install_path]).to eq ''
  end

  it 'inits a new file' do
    expect(!File.exist?('runner.conf'))
    OpenStudio::Extension::RunnerConfig.init(Dir.pwd.to_s)
    expect(File.exist?('runner.conf'))
  end

  it 'should allow additional config options to exist' do
    run_config = OpenStudio::Extension::RunnerConfig.new(Dir.pwd.to_s)
    run_config.add_config_option('new_field', 123.456)

    expect(run_config.options[:new_field]).to eq 123.456

    # make sure it can be saved
    run_config.save

    # load the file and make sure new option exists
    j = JSON.parse(File.read('runner.conf'), symbolize_names: true)
    expect(j[:new_field]).to eq 123.456
  end

  it 'should not allow new unallowed config options' do
    run_config = OpenStudio::Extension::RunnerConfig.new(Dir.pwd.to_s)
    expect { run_config.add_config_option('num_parallel', 42) }.to raise_error(/num_parallel/)
  end

  it 'should update field' do
    run_config = OpenStudio::Extension::RunnerConfig.new(Dir.pwd.to_s)
    run_config.update_config('max_datapoints', 2468)

    expect(run_config.options[:max_datapoints]).to eq 2468

    # make sure it can be saved
    run_config.save

    # load the file and make sure new option exists
    j = JSON.parse(File.read('runner.conf'), symbolize_names: true)
    expect(j[:max_datapoints]).to eq 2468
  end

  it 'should fail on update of null field' do
    run_config = OpenStudio::Extension::RunnerConfig.new(Dir.pwd.to_s)
    expect { run_config.update_config('dne_key', 42) }.to raise_error(/Could not find key/)
  end
end
