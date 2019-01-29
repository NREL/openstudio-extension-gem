########################################################################################################################
#  openstudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
#  following conditions are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#  disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#  following disclaimer in the documentation and/or other materials provided with the distribution.
#
#  (3) Neither the name of the copyright holder nor the names of any contributors may be used to endorse or promote
#  products derived from this software without specific prior written permission from the respective party.
#
#  (4) Other than as required in clauses (1) and (2), distributions in any form of modifications or other derivative
#  works may not use the "openstudio" trademark, "OS", "os", or any other confusingly similar designation without
#  specific prior written permission from Alliance for Sustainable Energy, LLC.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR
#  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
#  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################################################################

require 'json'
require 'fileutils'

RSpec.describe OpenStudio::Extension::Runner do
  it 'can run an OSW' do
    extension = OpenStudio::Extension::Extension.new
    runner = OpenStudio::Extension::Runner.new(extension.root_dir)
    in_osw_path = File.join(File.dirname(__FILE__), '../files/in.osw')
    expect(File.exists?(in_osw_path)).to be true
    
    in_osw = {}
    File.open(in_osw_path, 'r') do |file|
      in_osw = JSON.parse(file.read, {symbolize_names: true})
    end
    expect(in_osw[:seed_file]).to be nil
    expect(in_osw[:weather_file]).to eq("openstudio-extension-gem-test.epw")
    expect(in_osw[:measure_paths]).to be_empty
    expect(in_osw[:file_paths]).to be_empty
    
    run_dir = File.join(File.dirname(__FILE__), '../test/runner/')
    run_osw_path = File.join(run_dir, 'in.osw')
    out_osw_path = File.join(run_dir, 'out.osw')
    
    if File.exists?(run_dir)
      FileUtils.rm_rf(run_dir)
    end
    expect(File.exists?(run_dir)).to be false
    expect(File.exists?(run_osw_path)).to be false
    
    FileUtils.mkdir_p(run_dir)
    expect(File.exists?(run_dir)).to be true

    result = runner.run_osw(in_osw, run_dir)
    
    expect(File.exists?(run_osw_path)).to be true
    expect(File.exists?(out_osw_path)).to be true
    
  end
  
end
