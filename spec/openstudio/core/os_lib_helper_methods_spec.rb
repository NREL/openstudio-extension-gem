# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
