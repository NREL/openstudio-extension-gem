# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'json'
require 'parallel'

RSpec.describe OpenStudio::Extension::RunnerConfig do
  before :each do
    @test_folder = File.join(File.dirname(__FILE__), "test_defaults")
    if File.exist?(@test_folder)
      FileUtils.rm_rf(@test_folder)
    end

    FileUtils.mkdir_p(@test_folder)
  end

  it 'has defaults' do
    defaults = OpenStudio::Extension::RunnerConfig.default_config(@test_folder)
    expect(defaults[:max_datapoints]).to eq 1E9.to_i
    expect(defaults[:num_parallel]).to eq Parallel.processor_count
    expect(defaults[:run_simulations]).to eq true
    expect(defaults[:verbose]).to eq false
    expect(defaults[:gemfile_path]).to eq ''
    expect(defaults[:bundle_install_path]).to eq File.join(@test_folder, '.bundle/install/')
  end

  it 'respects bundle config when getting defaults' do
    bundle_dir = File.join(@test_folder, '.bundle')
    FileUtils.mkdir_p(bundle_dir)
    File.write(File.join(bundle_dir, 'config'), 'BUNDLE_PATH: "mycustom_bundle"')
    File.write(File.join(@test_folder, 'Gemfile'), "source 'http://rubygems.org'")
    defaults = OpenStudio::Extension::RunnerConfig.default_config(@test_folder)
    expect(defaults[:max_datapoints]).to eq 1E9.to_i
    expect(defaults[:num_parallel]).to eq Parallel.processor_count
    expect(defaults[:run_simulations]).to eq true
    expect(defaults[:verbose]).to eq false
    expect(defaults[:gemfile_path]).to eq ''
    expect(defaults[:bundle_install_path]).to eq 'mycustom_bundle'
  end

  it 'inits a new file' do
    runner_conf = File.join(@test_folder, 'runner.conf')
    expect(!File.exist?(runner_conf))
    OpenStudio::Extension::RunnerConfig.init(@test_folder)
    expect(File.exist?(runner_conf))
  end

  it 'should allow additional config options to exist' do
    OpenStudio::Extension::RunnerConfig.init(@test_folder)
    run_config = OpenStudio::Extension::RunnerConfig.new(@test_folder)
    run_config.add_config_option('new_field', 123.456)

    expect(run_config.options[:new_field]).to eq 123.456

    # make sure it can be saved
    run_config.save

    # load the file and make sure new option exists
    j = JSON.parse(File.read(File.join(@test_folder, 'runner.conf')), symbolize_names: true)
    expect(j[:new_field]).to eq 123.456
  end

  it 'should not allow new unallowed config options' do
    OpenStudio::Extension::RunnerConfig.init(@test_folder)
    run_config = OpenStudio::Extension::RunnerConfig.new(@test_folder)
    expect { run_config.add_config_option('num_parallel', 42) }.to raise_error(/num_parallel/)
  end

  it 'should update field' do
    OpenStudio::Extension::RunnerConfig.init(@test_folder)
    run_config = OpenStudio::Extension::RunnerConfig.new(@test_folder)
    run_config.update_config('max_datapoints', 2468)

    expect(run_config.options[:max_datapoints]).to eq 2468

    # make sure it can be saved
    run_config.save

    # load the file and make sure new option exists
    j = JSON.parse(File.read(File.join(@test_folder, 'runner.conf')), symbolize_names: true)
    expect(j[:max_datapoints]).to eq 2468
  end

  it 'should fail on update of null field' do
    OpenStudio::Extension::RunnerConfig.init(@test_folder)
    run_config = OpenStudio::Extension::RunnerConfig.new(@test_folder)
    expect { run_config.update_config('dne_key', 42) }.to raise_error(/Could not find key/)
  end
end
