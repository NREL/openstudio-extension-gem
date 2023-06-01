# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

begin
  # load OpenStudio measure libraries from common location
  require 'openstudio/extension/core/os_lib_helper_methods'
rescue LoadError
  # common location unavailable, load from local resources
  require_relative 'resources/os_lib_helper_methods'
end

# start the measure
class OpenStudioExtensionTestMeasure < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see
  def name
    return 'OpenStudio Extension Test Measure'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    return true
  end
end

# this allows the measure to be used by the application
OpenStudioExtensionTestMeasure.new.registerWithApplication
