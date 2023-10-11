# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module OsLib_OutdoorAirAndInfiltration
  # delete any infiltration objects used in the model.
  def self.eraseInfiltrationUsedInModel(model, runner)
    # get space infiltration objects.
    space_infiltration_objects = model.getSpaceInfiltrationDesignFlowRates.sort

    # hash to hold schedules used for infiltration objects in the model
    @infiltrationSchedulesHardAssigned = {}

    def OsLib_OutdoorAirAndInfiltration.addScheduleToArrayAndRemove(space_infiltration_object)
      # get schedule and add to hash
      if !space_infiltration_object.isScheduleDefaulted
        if !space_infiltration_object.schedule.empty?
          schedule = space_infiltration_object.schedule.get
          if @infiltrationSchedulesHardAssigned.key?(schedule)
            @infiltrationSchedulesHardAssigned[schedule] = @infiltrationSchedulesHardAssigned[schedule] + 1
          else
            @infiltrationSchedulesHardAssigned[schedule] = 1
          end
        end
      end
      space_infiltration_object.remove
    end

    # remove space infiltration objects
    number_removed = 0
    number_left = 0
    space_infiltration_objects.each do |space_infiltration_object|
      opt_space_type = space_infiltration_object.spaceType
      if opt_space_type.empty?
        # add schedule if exists to array and remove object
        OsLib_OutdoorAirAndInfiltration.addScheduleToArrayAndRemove(space_infiltration_object)
        number_removed += 1
      elsif !opt_space_type.get.spaces.empty?
        # add schedule if exists to array and remove object
        OsLib_OutdoorAirAndInfiltration.addScheduleToArrayAndRemove(space_infiltration_object)
        number_removed += 1
      else
        number_left += 1
      end
    end
    if number_removed > 0
      runner.registerInfo("#{number_removed} infiltration objects were removed.")
    end
    if number_left > 0
      runner.registerInfo("#{number_left} infiltration objects in unused space types were left in the model. They will not be altered.")
    end

    result = @infiltrationSchedulesHardAssigned.sort_by { |k, v| v }.reverse # want schedule with largest key first
    return result
  end

  # create new infiltration def and apply it to all spaces throughout the entire building
  def self.addSpaceInfiltrationDesignFlowRate(model, runner, objects, options = {})
    # set defaults to use if user inputs not passed in
    defaults = {
      'nameSuffix' => ' - infiltration', # add this to object name for infiltration
      'defaultBuildingSchedule' => nil, # this will set schedule set for selected object
      'schedule' => nil, # this will hard assign a schedule
      'setCalculationMethod' => nil, # should be string like setFlowerExteriorSurfaceArea
      'valueForSelectedCalcMethod' => nil
    }

    # merge user inputs with defaults
    options = defaults.merge(options)
    building = model.getBuilding
    newSpaceInfiltrationObjects = []

    # set default building infiltration schedule if requested
    if !options['defaultBuildingSchedule'].nil?
      if !building.defaultScheduleSet.empty?
        defaultScheduleSet = building.defaultScheduleSet.get
      else
        defaultScheduleSet = OpenStudio::Model::DefaultScheduleSet.new(model)
        defaultScheduleSet.setName('Default Schedules')
        building.setDefaultScheduleSet(defaultScheduleSet)
      end
      # set requested default schedule
      defaultScheduleSet.setInfiltrationSchedule(options['defaultBuildingSchedule'])
    end

    # note: object should be the building, or an array of space and or space types
    if objects == building
      # if no default space type then add an empty one (to hold new space infiltration object)
      if building.spaceType.empty?
        new_default = OpenStudio::Model::SpaceType.new(model)
        new_default.setName('Building Default Space Type')
        building.setSpaceType(new_default)
        runner.registerInfo("Adding a building default space type to hold space infiltration for spaces that previously didn't have a space type.")
      end

      # change objects to be all space types used in the model
      objects = []
      space_types = model.getSpaceTypes.sort
      space_types.each do |space_type|
        if !space_type.spaces.empty?
          objects << space_type
        end
      end
    end

    # loop through objects
    objects.each do |object|
      # create the infiltration object and associate with space or space type
      new_infil = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      newSpaceInfiltrationObjects << new_infil
      eval("new_infil.#{options['setCalculationMethod']}(#{options['valueForSelectedCalcMethod']})")
      if !object.to_SpaceType.empty?
        new_infil.setSpaceType(object)
      elsif !object.to_Space.empty?
        new_infil.setSpace(object)
      else
        runner.registerWarning("#{object.name} isn't a space or a space type. Can't assign infiltration object to it.")
      end
      new_infil.setName("#{object.name} #{options['nameSuffix']}")

      # set hard assigned schedule if requested
      if options['schedule']
        new_infil.setSchedule(options['schedule'])
      end

      if new_infil.schedule.empty?
        runner.registerWarning("The new infiltration object for space type '#{object.name}' does not have a schedule. Assigning a default schedule set including an infiltration schedule to the space type or the building will address this.")
      end
    end

    result = newSpaceInfiltrationObjects
    return result
  end
end
