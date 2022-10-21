# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
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
