# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
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

# TODO: should we load all this files when we require 'openstudio/extension'? I vote yes, but have to be careful with
# conflicts.
require 'openstudio/extension/core/os_lib_helper_methods'

RSpec.describe 'OS Lib Helper Methods' do
  context 'test methods' do
    before :all do
      @model = OpenStudio::Model.exampleModel

      # create an instance of a runner with OSW
      target_path = File.expand_path('../../files', File.dirname(__FILE__))
      osw_path = OpenStudio::Path.new("#{target_path}/model_test.osw")
      osw = OpenStudio::WorkflowJSON.load(osw_path).get
      @runner = OpenStudio::Measure::OSRunner.new(osw)
    end

    it 'floor area and exterior wall area from spaces in model' do
      spaces = []
      @model.getSpaces.each do |space|
        spaces << space
      end

      # floor area of spaces
      res = OsLib_HelperMethods.getAreaOfSpacesInArray(@model, spaces)
      expect(res['totalArea']).to eq 400.0

      # exterior wall area of spaces
      res = OsLib_HelperMethods.getAreaOfSpacesInArray(@model, spaces, 'exteriorWallArea')
      expect(res['totalArea']).to eq 240.0
    end

    it 'check upstream argument values in upstream measure from test osw' do
      # use of template as string
      res = OsLib_HelperMethods.check_upstream_measure_for_arg(@runner, 'template')
      expect(res[:value]).to eq '90.1-2010'

      # use of template as double
      res = OsLib_HelperMethods.check_upstream_measure_for_arg(@runner, 'elec_rate')
      expect(res[:value]).to eq 0.12

      # use of template as integer
      res = OsLib_HelperMethods.check_upstream_measure_for_arg(@runner, 'expected_life')
      expect(res[:value]).to eq 15

      # use of template as bool
      res = OsLib_HelperMethods.check_upstream_measure_for_arg(@runner, 'demo_cost_initial_const')
      expect(res[:value]).to eq false
    end
  end
end
