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

require 'json'
require 'fileutils'

RSpec.describe OpenStudio::Extension::Runner do
  it 'can use runner.conf' do
    # Add in a runner
    File.delete('runner.conf') if File.exist? 'runner.conf'
    OpenStudio::Extension::RunnerConfig.init(Dir.pwd)

    # load the new runner
    run_config = OpenStudio::Extension::RunnerConfig.new(Dir.pwd.to_s)
    run_config.update_config('num_parallel', 2.456)
    run_config.save

    extension = OpenStudio::Extension::Extension.new
    runner = OpenStudio::Extension::Runner.new(extension.root_dir)

    # Verify that the options is being set from the runner.conf file by inspecting that the
    # num_parallel changed in the runner config
    expect(runner.options[:num_parallel]).to eq 2.456
    # remove file
    File.delete('runner.conf') if File.exist? 'runner.conf'
    expect(File.exist?('runner.conf')).to eq false
  end

  it 'can run an OSW' do
    extension = OpenStudio::Extension::Extension.new
    runner_options = { run_simulations: true }
    runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
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

    run_dir = File.join(File.dirname(__FILE__), '../test/runner/')
    run_osw_path = File.join(run_dir, 'in.osw')
    out_osw_path = File.join(run_dir, 'out.osw')
    failed_job_path = File.join(run_dir, 'failed.job')

    if File.exist?(run_dir)
      FileUtils.rm_rf(run_dir)
    end
    expect(File.exist?(run_dir)).to be false
    expect(File.exist?(run_osw_path)).to be false
    expect(File.exist?(failed_job_path)).to be false

    FileUtils.mkdir_p(run_dir)
    expect(File.exist?(run_dir)).to be true

    result = runner.run_osw(in_osw, run_dir)
    expect(result).to be true

    expect(File.exist?(run_osw_path)).to be true
    expect(File.exist?(out_osw_path)).to be true
    expect(File.exist?(failed_job_path)).to be false
  end

  it 'does not run an OSW' do
    extension = OpenStudio::Extension::Extension.new
    runner_options = { run_simulations: false }
    runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
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

    run_dir = File.join(File.dirname(__FILE__), '../test/runner/')
    run_osw_path = File.join(run_dir, 'in.osw')
    out_osw_path = File.join(run_dir, 'out.osw')
    failed_job_path = File.join(run_dir, 'failed.job')

    if File.exist?(run_dir)
      FileUtils.rm_rf(run_dir)
    end
    expect(File.exist?(run_dir)).to be false
    expect(File.exist?(run_osw_path)).to be false
    expect(File.exist?(failed_job_path)).to be false

    FileUtils.mkdir_p(run_dir)
    expect(File.exist?(run_dir)).to be true

    result = runner.run_osw(in_osw, run_dir)
    expect(result).to be nil

    expect(File.exist?(run_osw_path)).to be true
    expect(File.exist?(out_osw_path)).to be false
    expect(File.exist?(failed_job_path)).to be false
  end

  it 'can find a measure in the OSW' do
    extension = OpenStudio::Extension::Extension.new
    runner_options = { run_simulations: true }
    runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
    in_osw_path = File.join(File.dirname(__FILE__), '../files/in.osw')
    expect(File.exist?(in_osw_path)).to be true

    in_osw = {}
    File.open(in_osw_path, 'r') do |file|
      in_osw = JSON.parse(file.read, symbolize_names: true)
    end

    found_measure = OpenStudio::Extension.measure_in_osw(in_osw, 'openstudio_extension_test_measure')
    expect(found_measure).to be true
  end

  it 'does not find a measure in the OSW' do
    extension = OpenStudio::Extension::Extension.new
    runner_options = { run_simulations: true }
    runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
    in_osw_path = File.join(File.dirname(__FILE__), '../files/in.osw')
    expect(File.exist?(in_osw_path)).to be true

    in_osw = {}
    File.open(in_osw_path, 'r') do |file|
      in_osw = JSON.parse(file.read, symbolize_names: true)
    end

    found_measure = OpenStudio::Extension.measure_in_osw(in_osw, 'measure_that_does_not_exist_in_osw')
    expect(found_measure).to be false
  end
end
