# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'

require_relative '../measure'
require 'minitest/autorun'

class OpenStudioExtensionTestMeasureTest < Minitest::Test
  # def setup
  # end

  # def teardown
  # end

  def test_OpenStudioExtensionTestMeasure
    # create an instance of the measure
    measure = OpenStudioExtensionTestMeasure.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    measure.run(model, runner, argument_map)
    result = runner.result
    # show_output(result)
    assert(result.value.valueName == 'Success')
    assert(result.warnings.empty?)
    assert(result.info.empty?)
  end
end
