# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

RSpec.describe OpenStudio::Extension do
  it 'has a version number' do
    expect(OpenStudio::Extension::VERSION).not_to be nil
  end

  it 'has a measures directory' do
    extension = OpenStudio::Extension::Extension.new
    measures_dir = extension.measures_dir
    expect(measures_dir).not_to be nil
    expect(File.directory?(measures_dir)).to be true
    expect(File.exist?(measures_dir)).to be true
    expect(File.exist?(File.join(measures_dir, 'openstudio_extension_test_measure/measure.rb'))).to be true
  end

  it 'has a files directory' do
    extension = OpenStudio::Extension::Extension.new
    files_dir = extension.files_dir
    expect(files_dir).not_to be nil
    expect(File.directory?(files_dir)).to be true
    expect(File.exist?(files_dir)).to be true
    expect(File.exist?(File.join(files_dir, 'openstudio-extension-gem-test.epw'))).to be true
  end

  it 'has a core directory' do
    extension = OpenStudio::Extension::Extension.new
    core_dir = extension.core_dir
    expect(core_dir).not_to be nil
    expect(File.directory?(core_dir)).to be true
    expect(File.exist?(core_dir)).to be true
    expect(File.exist?(File.join(core_dir, 'os_lib_helper_methods.rb'))).to be true
  end

  it 'has a doc templates directory' do
    extension = OpenStudio::Extension::Extension.new
    doc_templates_dir = extension.doc_templates_dir
    expect(doc_templates_dir).not_to be nil
    expect(File.directory?(doc_templates_dir)).to be true
    expect(File.exist?(doc_templates_dir)).to be true
    expect(File.exist?(File.join(doc_templates_dir, 'LICENSE.md'))).to be true
  end

  it 'has a root directory' do
    extension = OpenStudio::Extension::Extension.new
    root_dir = extension.root_dir
    expect(root_dir).not_to be nil
    expect(File.directory?(root_dir)).to be true
    expect(File.exist?(root_dir)).to be true
    expect(File.exist?(File.join(root_dir, 'Gemfile'))).to be true
  end

  it 'has module methods' do
    expect(OpenStudio::Extension.check_for_name_conflicts).to be false
    expect(OpenStudio::Extension.all_extensions.size).to eq(1)
    expect(OpenStudio::Extension.all_measure_dirs.size).to eq(1)
    expect(OpenStudio::Extension.all_file_dirs.size).to eq(1)

    expect(File.exist?(File.join(OpenStudio::Extension.all_measure_dirs[0], 'openstudio_extension_test_measure/measure.rb'))).to be true
    expect(File.exist?(File.join(OpenStudio::Extension.all_file_dirs, 'openstudio-extension-gem-test.epw'))).to be true
  end

  it 'configures an OSW' do
    # extension = OpenStudio::Extension::Extension.new
    # runner = OpenStudio::Extension::Runner.new(extension.root_dir)
    in_osw_path = File.join(File.dirname(__FILE__), '../files/in.osw')
    expect(File.exist?(in_osw_path)).to be true

    in_osw = {}
    File.open(in_osw_path, 'r') do |file|
      in_osw = JSON.parse(file.read, symbolize_names: true)
    end
    expect(in_osw[:seed_file]).to be nil
    expect(in_osw[:weather_file]).to eq('openstudio-extension-gem-test.epw')
    expect(in_osw[:measure_paths]).to be_empty
    expect(in_osw[:file_paths]).to be_empty

    run_osw = OpenStudio::Extension.configure_osw(in_osw)
    expect(run_osw[:seed_file]).to be nil
    expect(run_osw[:weather_file]).to eq('openstudio-extension-gem-test.epw')
    expect(run_osw[:measure_paths]).not_to be_empty
    expect(run_osw[:file_paths]).not_to be_empty

    run_osw[:measure_paths].each do |p|
      expect(File.exist?(p)).to be true
    end
    run_osw[:file_paths].each do |p|
      expect(File.exist?(p)).to be true
    end
  end
end
