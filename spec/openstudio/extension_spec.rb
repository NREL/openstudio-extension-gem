# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
