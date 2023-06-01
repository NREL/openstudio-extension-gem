# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module OsLib_HVAC
  # do something
  def self.doSomething(input)
    # do something
    output = input

    result = output
    return result
  end

  # validate and make plenum zones
  def self.validateAndAddPlenumZonesToSystem(model, runner, options = {})
    # set defaults to use if user inputs not passed in
    defaults = {
      'zonesPlenum' => nil,
      'zonesPrimary' => nil,
      'type' => 'ceilingReturn'
    }

    # merge user inputs with defaults
    options = defaults.merge(options)

    # array of valid ceiling plenums
    zoneSurfaceHash = {}
    zonePlenumHash = {}

    if options['zonesPlenum'].nil?
      runner.registerWarning('No plenum zones were passed in, validateAndAddPlenumZonesToSystem will not alter the model.')
    else
      options['zonesPlenum'].each do |zone|
        # get spaces in zone
        spaces = zone.spaces
        # get adjacent spaces
        spaces.each do |space|
          # get surfaces
          surfaces = space.surfaces
          # loop through surfaces looking for floors with surface boundary condition, grab zone that surface's parent space is in.
          surfaces.each do |surface|
            if (surface.outsideBoundaryCondition == 'Surface') && (surface.surfaceType == 'Floor')
              next if surface.adjacentSurface.empty?
              adjacentSurface = surface.adjacentSurface.get
              next if adjacentSurface.space.empty?
              adjacentSurfaceSpace = adjacentSurface.space.get
              next if adjacentSurfaceSpace.thermalZone.empty?
              adjacentSurfaceSpaceZone = adjacentSurfaceSpace.thermalZone.get
              if options['zonesPrimary'].include? adjacentSurfaceSpaceZone
                if zoneSurfaceHash[adjacentSurfaceSpaceZone].nil? || (surface.grossArea > zoneSurfaceHash[adjacentSurfaceSpaceZone])
                  adjacentSurfaceSpaceZone.setReturnPlenum(zone)
                  zoneSurfaceHash[adjacentSurfaceSpaceZone] = surface.grossArea
                  zonePlenumHash[adjacentSurfaceSpaceZone] = zone
                end
              end
            end
          end
        end
      end
    end

    # report out results of zone-plenum hash
    zonePlenumHash.each do |zone, plenum|
      runner.registerInfo("#{plenum.name} has been set as a return air plenum for #{zone.name}.")
    end

    # pass back zone-plenum hash
    result = zonePlenumHash
    return result
  end

  def self.sortZones(model, runner, options = {})
    # set defaults to use if user inputs not passed in
    defaults = { 'standardBuildingTypeTest' => nil, # not used for now
                 'secondarySpaceTypeTest' => nil,
                 'ceilingReturnPlenumSpaceType' => nil }

    # merge user inputs with defaults
    options = defaults.merge(options)

    # set up zone type arrays
    zonesPrimary = []
    zonesSecondary = []
    zonesPlenum = []
    zonesUnconditioned = []

    # get thermal zones
    zones = model.getThermalZones.sort
    zones.each do |zone|
      # assign appropriate zones to zonesPlenum or zonesUnconditioned (those that don't have thermostats or zone HVAC equipment)
      # if not conditioned then add to zonesPlenum or zonesUnconditioned
      if zone.thermostatSetpointDualSetpoint.is_initialized || !zone.equipment.empty?
        # zone is conditioned.  check if its space type is secondary or primary
        spaces = zone.spaces
        spaces.each do |space|
          # if a zone has already been assigned as secondary, skip
          next if zonesSecondary.include? zone
          # get space type if it exists
          next if space.spaceType.empty?
          spaceType = space.spaceType.get
          # get standards information
          # for now skip standardsBuildingType and just rely on the standardsSpaceType. Seems like enough.
          next if spaceType.standardsSpaceType.empty?
          standardSpaceType = spaceType.standardsSpaceType.get
          # test space type against secondary space type array
          # if any space type in zone is secondary, assign zone as secondary
          if options['secondarySpaceTypeTest'].include? standardSpaceType
            zonesSecondary << zone
          end
        end
        # if zone not assigned as secondary, assign as primary
        unless zonesSecondary.include? zone
          zonesPrimary << zone
        end
      else
        # determine if zone is a plenum zone or general unconditioned zone
        # assume it is a plenum if it has at least one planum space
        zone.spaces.each do |space|
          # if a zone has already been assigned as a plenum, skip
          next if zonesPlenum.include? zone
          # if zone not assigned as a plenum, get space type if it exists
          # compare to plenum space type if it has been assigned
          if space.spaceType.is_initialized && (options['ceilingReturnPlenumSpaceType'].nil? == false)
            spaceType = space.spaceType.get
            if spaceType == options['ceilingReturnPlenumSpaceType']
              zonesPlenum << zone # zone has a plenum space; assign it as a plenum
            end
          end
        end
        # if zone not assigned as a plenum, assign it as unconditioned
        unless zonesPlenum.include? zone
          zonesUnconditioned << zone
        end
      end
    end

    zonesSorted = { 'zonesPrimary' => zonesPrimary,
                    'zonesSecondary' => zonesSecondary,
                    'zonesPlenum' => zonesPlenum,
                    'zonesUnconditioned' => zonesUnconditioned }
    # pass back zonesSorted hash
    result = zonesSorted
    return result
  end

  def self.reportConditions(model, runner, condition,extra_string = '')

    airloops = model.getAirLoopHVACs.sort
    plantLoops = model.getPlantLoops.sort
    zones = model.getThermalZones.sort

    # count up zone equipment (not counting zone exhaust fans)
    zoneHasEquip = false
    zonesWithEquipCounter = 0

    zones.each do |zone|
      if zone.equipment.size > 0
        zone.equipment.each do |equip|
          unless equip.to_FanZoneExhaust.is_initialized
            zonesWithEquipCounter += 1
            break
          end
        end
      end
    end

    if condition == "initial"
      runner.registerInitialCondition("The building started with #{airloops.size} air loops and #{plantLoops.size} plant loops. #{zonesWithEquipCounter} zones were conditioned with zone equipment.")
    elsif condition == "final"
      runner.registerFinalCondition("The building finished with #{airloops.size} air loops and #{plantLoops.size} plant loops. #{zonesWithEquipCounter} zones are conditioned with zone equipment. #{extra_string}")
    end

  end

  def self.removeEquipment(model, runner)
    airloops = model.getAirLoopHVACs.sort
    plantLoops = model.getPlantLoops.sort
    zones = model.getThermalZones.sort

    # remove all airloops
    airloops.each(&:remove)

    # remove all zone equipment except zone exhaust fans
    zones.each do |zone|
      zone.equipment.each do |equip|
        if equip.to_FanZoneExhaust.is_initialized
        else
          equip.remove
        end
      end
    end

    # remove plant loops
    plantLoops.each do |plantloop|
      # get the demand components and see if water use connection, then save it
      # notify user with info statement if supply side of plant loop had heat exchanger for refrigeration
      usedForSHWorRefrigeration = false
      plantloop.demandComponents.each do |comp| # AP code to check your comments above
        if comp.to_WaterUseConnections.is_initialized || comp.to_CoilWaterHeatingDesuperheater.is_initialized
          usedForSHWorRefrigeration = true
        end
      end
      if usedForSHWorRefrigeration == false
        plantloop.remove
      else
        runner.registerWarning("#{plantloop.name} is used for SHW or refrigeration heat reclaim.  Loop will not be deleted")
      end
    end
  end

  def self.assignHVACSchedules(model, runner, options = {})
    require "#{File.dirname(__FILE__)}/os_lib_schedules"

    schedulesHVAC = {}
    airloops = model.getAirLoopHVACs.sort

    # find airloop with most primary spaces
    max_primary_spaces = 0
    representative_airloop = false
    building_HVAC_schedule = false
    building_ventilation_schedule = false
    unless options['remake_schedules']
      # if remake schedules not selected, get relevant schedules from model if they exist
      airloops.each do |air_loop|
        primary_spaces = 0
        air_loop.thermalZones.each do |thermal_zone|
          thermal_zone.spaces.each do |space|
            if space.spaceType.is_initialized
              if space.spaceType.get.name.get.include? options['primarySpaceType']
                primary_spaces += 1
              end
            end
          end
        end
        if primary_spaces > max_primary_spaces
          max_primary_spaces = primary_spaces
          representative_airloop = air_loop
        end
      end
    end
    if representative_airloop
      building_HVAC_schedule = representative_airloop.availabilitySchedule
      building_ventilation_schedule_optional = representative_airloop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir.maximumFractionofOutdoorAirSchedule
      if building_ventilation_schedule_optional.is_initialized
        building_ventilation_schedule = building_ventilation_schedule.get
      end
    end
    # build new airloop schedules if existing model doesn't have them
    if options['primarySpaceType'] == 'Classroom'
      # ventilation schedule
      unless building_ventilation_schedule
        ruleset_name = 'AEDG K-12 Ventilation Schedule'
        winter_design_day = [[24, 1]]
        summer_design_day = [[24, 1]]
        default_day = ['Weekday', [6, 0], [18, 1], [24, 0]]
        rules = []
        rules << ['Weekend', '1/1-12/31', 'Sat/Sun', [24, 0]]
        rules << ['Summer Weekday', '7/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [8, 0], [13, 1], [24, 0]]
        options_ventilation = { 'name' => ruleset_name,
                                'winter_design_day' => winter_design_day,
                                'summer_design_day' => summer_design_day,
                                'default_day' => default_day,
                                'rules' => rules }
        building_ventilation_schedule = OsLib_Schedules.createComplexSchedule(model, options_ventilation)
      end
      # HVAC availability schedule
      unless building_HVAC_schedule
        ruleset_name = 'AEDG K-12 HVAC Availability Schedule'
        winter_design_day = [[24, 1]]
        summer_design_day = [[24, 1]]
        default_day = ['Weekday', [6, 0], [18, 1], [24, 0]]
        rules = []
        rules << ['Weekend', '1/1-12/31', 'Sat/Sun', [24, 0]]
        rules << ['Summer Weekday', '7/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [8, 0], [13, 1], [24, 0]]
        options_hvac = { 'name' => ruleset_name,
                         'winter_design_day' => winter_design_day,
                         'summer_design_day' => summer_design_day,
                         'default_day' => default_day,
                         'rules' => rules }
        building_HVAC_schedule = OsLib_Schedules.createComplexSchedule(model, options_hvac)
      end
    elsif options['primarySpaceType'] == 'Office'
      # ventilation schedule
      unless building_ventilation_schedule
        ruleset_name = 'AEDG Office Ventilation Schedule'
        winter_design_day = [[24, 1]] # ML These are not always on in PNNL model
        summer_design_day = [[24, 1]] # ML These are not always on in PNNL model
        default_day = ['Weekday', [7, 0], [22, 1], [24, 0]] # ML PNNL has a one hour ventilation offset
        rules = []
        rules << ['Saturday', '1/1-12/31', 'Sat', [7, 0], [18, 1], [24, 0]] # ML PNNL has a one hour ventilation offset
        rules << ['Sunday', '1/1-12/31', 'Sun', [24, 0]]
        options_ventilation = { 'name' => ruleset_name,
                                'winter_design_day' => winter_design_day,
                                'summer_design_day' => summer_design_day,
                                'default_day' => default_day,
                                'rules' => rules }
        building_ventilation_schedule = OsLib_Schedules.createComplexSchedule(model, options_ventilation)
      end
      # HVAC availability schedule
      unless building_HVAC_schedule
        ruleset_name = 'AEDG Office HVAC Availability Schedule'
        winter_design_day = [[24, 1]] # ML These are not always on in PNNL model
        summer_design_day = [[24, 1]] # ML These are not always on in PNNL model
        default_day = ['Weekday', [6, 0], [22, 1], [24, 0]] # ML PNNL has a one hour ventilation offset
        rules = []
        rules << ['Saturday', '1/1-12/31', 'Sat', [6, 0], [18, 1], [24, 0]] # ML PNNL has a one hour ventilation offset
        rules << ['Sunday', '1/1-12/31', 'Sun', [24, 0]]
        options_hvac = { 'name' => ruleset_name,
                         'winter_design_day' => winter_design_day,
                         'summer_design_day' => summer_design_day,
                         'default_day' => default_day,
                         'rules' => rules }
        building_HVAC_schedule = OsLib_Schedules.createComplexSchedule(model, options_hvac)
      end
      # special loops for radiant system (different temperature setpoints)
      if options['allHVAC']['zone'] == 'Radiant'
        # create hot water schedule for radiant heating loop
        schedulesHVAC['radiant_hot_water'] = OsLib_Schedules.createComplexSchedule(model, 'name' => 'AEDG HW-Radiant-Loop-Temp-Schedule',
                                                                                          'default_day' => ['All Days', [24, 45.0]])
        # create hot water schedule for radiant cooling loop
        schedulesHVAC['radiant_chilled_water'] = OsLib_Schedules.createComplexSchedule(model, 'name' => 'AEDG CW-Radiant-Loop-Temp-Schedule',
                                                                                              'default_day' => ['All Days', [24, 15.0]])
        # create mean radiant heating and cooling setpoint schedules
        # ML ideally, should grab schedules tied to zone thermostat and make modified versions that follow the setback pattern
        # for now, create new ones that match the recommended HVAC schedule
        # mean radiant heating setpoint schedule (PNNL values)
        ruleset_name = 'AEDG Office Mean Radiant Heating Setpoint Schedule'
        winter_design_day = [[24, 18.8]]
        summer_design_day = [[6, 18.3], [22, 18.8], [24, 18.3]]
        default_day = ['Weekday', [6, 18.3], [22, 18.8], [24, 18.3]]
        rules = []
        rules << ['Saturday', '1/1-12/31', 'Sat', [6, 18.3], [18, 18.8], [24, 18.3]]
        rules << ['Sunday', '1/1-12/31', 'Sun', [24, 18.3]]
        options_radiant_heating = { 'name' => ruleset_name,
                                    'winter_design_day' => winter_design_day,
                                    'summer_design_day' => summer_design_day,
                                    'default_day' => default_day,
                                    'rules' => rules }
        mean_radiant_heating_schedule = OsLib_Schedules.createComplexSchedule(model, options_radiant_heating)
        schedulesHVAC['mean_radiant_heating'] = mean_radiant_heating_schedule
        # mean radiant cooling setpoint schedule (PNNL values)
        ruleset_name = 'AEDG Office Mean Radiant Cooling Setpoint Schedule'
        winter_design_day = [[6, 26.7], [22, 24.0], [24, 26.7]]
        summer_design_day = [[24, 24.0]]
        default_day = ['Weekday', [6, 26.7], [22, 24.0], [24, 26.7]]
        rules = []
        rules << ['Saturday', '1/1-12/31', 'Sat', [6, 26.7], [18, 24.0], [24, 26.7]]
        rules << ['Sunday', '1/1-12/31', 'Sun', [24, 26.7]]
        options_radiant_cooling = { 'name' => ruleset_name,
                                    'winter_design_day' => winter_design_day,
                                    'summer_design_day' => summer_design_day,
                                    'default_day' => default_day,
                                    'rules' => rules }
        mean_radiant_cooling_schedule = OsLib_Schedules.createComplexSchedule(model, options_radiant_cooling)
        schedulesHVAC['mean_radiant_cooling'] = mean_radiant_cooling_schedule
      end
    end
    # SAT schedule
    if options['allHVAC']['primary']['doas']
      # primary airloop is DOAS
      schedulesHVAC['primary_sat'] = sch_ruleset_DOAS_setpoint = OsLib_Schedules.createComplexSchedule(model,  'name' => 'AEDG DOAS Temperature Setpoint Schedule',
                                                                                                               'default_day' => ['All Days', [24, 20.0]])
    else
      # primary airloop is multizone VAV that cools
      schedulesHVAC['primary_sat'] = sch_ruleset_DOAS_setpoint = OsLib_Schedules.createComplexSchedule(model,  'name' => 'AEDG Cold Deck Temperature Setpoint Schedule',
                                                                                                               'default_day' => ['All Days', [24, 12.8]])
    end
    schedulesHVAC['ventilation'] = building_ventilation_schedule
    schedulesHVAC['hvac'] = building_HVAC_schedule
    # build new plant schedules as needed
    zoneHVACHotWaterPlant = ['FanCoil', 'DualDuct', 'Baseboard'] # dual duct has fan coil and baseboard
    zoneHVACChilledWaterPlant = ['FanCoil', 'DualDuct'] # dual duct has fan coil
    # hot water
    if (options['allHVAC']['primary']['heat'] == 'Water') || (options['allHVAC']['secondary']['heat'] == 'Water') || zoneHVACHotWaterPlant.include?(options['allHVAC']['zone'])
      schedulesHVAC['hot_water'] = OsLib_Schedules.createComplexSchedule(model,  'name' => 'AEDG HW-Loop-Temp-Schedule',
                                                                                 'default_day' => ['All Days', [24, 67.0]])
    end
    # chilled water
    if (options['allHVAC']['primary']['cool'] == 'Water') || (options['allHVAC']['secondary']['cool'] == 'Water') || zoneHVACChilledWaterPlant.include?(options['allHVAC']['zone'])
      schedulesHVAC['chilled_water'] = OsLib_Schedules.createComplexSchedule(model, 'name' => 'AEDG CW-Loop-Temp-Schedule',
                                                                                    'default_day' => ['All Days', [24, 6.7]])
    end
    # heat pump condenser loop schedules
    if options['allHVAC']['zone'] == 'GSHP'
      # there will be a heat pump condenser loop
      # loop setpoint schedule
      schedulesHVAC['hp_loop'] = OsLib_Schedules.createComplexSchedule(model, 'name' => 'AEDG HP-Loop-Temp-Schedule',
                                                                              'default_day' => ['All Days', [24, 21]])
      # cooling component schedule (#ML won't need this if a ground loop is actually modeled)
      schedulesHVAC['hp_loop_cooling'] = OsLib_Schedules.createComplexSchedule(model,  'name' => 'AEDG HP-Loop-Clg-Temp-Schedule',
                                                                                       'default_day' => ['All Days', [24, 21]])
      # heating component schedule
      schedulesHVAC['hp_loop_heating'] = OsLib_Schedules.createComplexSchedule(model,  'name' => 'AEDG HP-Loop-Htg-Temp-Schedule',
                                                                                       'default_day' => ['All Days', [24, 5]])
    end
    if options['allHVAC']['zone'] == 'WSHP'
      # there will be a heat pump condenser loop
      # loop setpoint schedule
      schedulesHVAC['hp_loop'] = OsLib_Schedules.createComplexSchedule(model, 'name' => 'AEDG HP-Loop-Temp-Schedule',
                                                                              'default_day' => ['All Days', [24, 30]]) # PNNL
      # cooling component schedule (#ML won't need this if a ground loop is actually modeled)
      schedulesHVAC['hp_loop_cooling'] = OsLib_Schedules.createComplexSchedule(model,  'name' => 'AEDG HP-Loop-Clg-Temp-Schedule',
                                                                                       'default_day' => ['All Days', [24, 30]]) # PNNL
      # heating component schedule
      schedulesHVAC['hp_loop_heating'] = OsLib_Schedules.createComplexSchedule(model,  'name' => 'AEDG HP-Loop-Htg-Temp-Schedule',
                                                                                       'default_day' => ['All Days', [24, 20]]) # PNNL
    end

    # pass back schedulesHVAC hash
    result = schedulesHVAC
    return result
  end

  def self.createHotWaterPlant(model, runner, hot_water_setpoint_schedule, loop_type)
    hot_water_plant = OpenStudio::Model::PlantLoop.new(model)
    hot_water_plant.setName("AEDG #{loop_type} Loop")
    hot_water_plant.setMaximumLoopTemperature(100)
    hot_water_plant.setMinimumLoopTemperature(10)
    loop_sizing = hot_water_plant.sizingPlant
    loop_sizing.setLoopType('Heating')
    if loop_type == 'Hot Water'
      loop_sizing.setDesignLoopExitTemperature(82)
    elsif loop_type == 'Radiant Hot Water'
      loop_sizing.setDesignLoopExitTemperature(60) # ML follows convention of sizing temp being larger than supplu temp
    end
    loop_sizing.setLoopDesignTemperatureDifference(11)
    # create a pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedPumpHead(119563) # Pa
    pump.setMotorEfficiency(0.9)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
    # create a boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    boiler.setNominalThermalEfficiency(0.9)
    # create a scheduled setpoint manager
    setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, hot_water_setpoint_schedule)
    # create a supply bypass pipe
    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a supply outlet pipe
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand bypass pipe
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand inlet pipe
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand outlet pipe
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # connect components to plant loop
    # supply side components
    hot_water_plant.addSupplyBranchForComponent(boiler)
    hot_water_plant.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(hot_water_plant.supplyInletNode)
    pipe_supply_outlet.addToNode(hot_water_plant.supplyOutletNode)
    setpoint_manager_scheduled.addToNode(hot_water_plant.supplyOutletNode)
    # demand side components (water coils are added as they are added to airloops and zoneHVAC)
    hot_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(hot_water_plant.demandInletNode)
    pipe_demand_outlet.addToNode(hot_water_plant.demandOutletNode)

    # pass back hot water plant
    result = hot_water_plant
    return result
  end

  def self.createChilledWaterPlant(model, runner, chilled_water_setpoint_schedule, loop_type, chillerType)
    # chilled water plant
    chilled_water_plant = OpenStudio::Model::PlantLoop.new(model)
    chilled_water_plant.setName("AEDG #{loop_type} Loop")
    chilled_water_plant.setMaximumLoopTemperature(98)
    chilled_water_plant.setMinimumLoopTemperature(1)
    loop_sizing = chilled_water_plant.sizingPlant
    loop_sizing.setLoopType('Cooling')
    if loop_type == 'Chilled Water'
      loop_sizing.setDesignLoopExitTemperature(6.7)
    elsif loop_type == 'Radiant Chilled Water'
      loop_sizing.setDesignLoopExitTemperature(15)
    end
    loop_sizing.setLoopDesignTemperatureDifference(6.7)
    # create a pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedPumpHead(149453) # Pa
    pump.setMotorEfficiency(0.9)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
    # create a chiller
    if chillerType == 'WaterCooled'
      # create clgCapFuncTempCurve
      clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
      clgCapFuncTempCurve.setCoefficient1Constant(1.07E+00)
      clgCapFuncTempCurve.setCoefficient2x(4.29E-02)
      clgCapFuncTempCurve.setCoefficient3xPOW2(4.17E-04)
      clgCapFuncTempCurve.setCoefficient4y(-8.10E-03)
      clgCapFuncTempCurve.setCoefficient5yPOW2(-4.02E-05)
      clgCapFuncTempCurve.setCoefficient6xTIMESY(-3.86E-04)
      clgCapFuncTempCurve.setMinimumValueofx(0)
      clgCapFuncTempCurve.setMaximumValueofx(20)
      clgCapFuncTempCurve.setMinimumValueofy(0)
      clgCapFuncTempCurve.setMaximumValueofy(50)
      # create eirFuncTempCurve
      eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
      eirFuncTempCurve.setCoefficient1Constant(4.68E-01)
      eirFuncTempCurve.setCoefficient2x(-1.38E-02)
      eirFuncTempCurve.setCoefficient3xPOW2(6.98E-04)
      eirFuncTempCurve.setCoefficient4y(1.09E-02)
      eirFuncTempCurve.setCoefficient5yPOW2(4.62E-04)
      eirFuncTempCurve.setCoefficient6xTIMESY(-6.82E-04)
      eirFuncTempCurve.setMinimumValueofx(0)
      eirFuncTempCurve.setMaximumValueofx(20)
      eirFuncTempCurve.setMinimumValueofy(0)
      eirFuncTempCurve.setMaximumValueofy(50)
      # create eirFuncPlrCurve
      eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
      eirFuncPlrCurve.setCoefficient1Constant(1.41E-01)
      eirFuncPlrCurve.setCoefficient2x(6.55E-01)
      eirFuncPlrCurve.setCoefficient3xPOW2(2.03E-01)
      eirFuncPlrCurve.setMinimumValueofx(0)
      eirFuncPlrCurve.setMaximumValueofx(1.2)
      # construct chiller
      chiller = OpenStudio::Model::ChillerElectricEIR.new(model, clgCapFuncTempCurve, eirFuncTempCurve, eirFuncPlrCurve)
      chiller.setReferenceCOP(6.1)
      chiller.setCondenserType('WaterCooled')
      chiller.setChillerFlowMode('ConstantFlow')
    elsif chillerType == 'AirCooled'
      # create clgCapFuncTempCurve
      clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
      clgCapFuncTempCurve.setCoefficient1Constant(1.05E+00)
      clgCapFuncTempCurve.setCoefficient2x(3.36E-02)
      clgCapFuncTempCurve.setCoefficient3xPOW2(2.15E-04)
      clgCapFuncTempCurve.setCoefficient4y(-5.18E-03)
      clgCapFuncTempCurve.setCoefficient5yPOW2(-4.42E-05)
      clgCapFuncTempCurve.setCoefficient6xTIMESY(-2.15E-04)
      clgCapFuncTempCurve.setMinimumValueofx(0)
      clgCapFuncTempCurve.setMaximumValueofx(20)
      clgCapFuncTempCurve.setMinimumValueofy(0)
      clgCapFuncTempCurve.setMaximumValueofy(50)
      # create eirFuncTempCurve
      eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
      eirFuncTempCurve.setCoefficient1Constant(5.83E-01)
      eirFuncTempCurve.setCoefficient2x(-4.04E-03)
      eirFuncTempCurve.setCoefficient3xPOW2(4.68E-04)
      eirFuncTempCurve.setCoefficient4y(-2.24E-04)
      eirFuncTempCurve.setCoefficient5yPOW2(4.81E-04)
      eirFuncTempCurve.setCoefficient6xTIMESY(-6.82E-04)
      eirFuncTempCurve.setMinimumValueofx(0)
      eirFuncTempCurve.setMaximumValueofx(20)
      eirFuncTempCurve.setMinimumValueofy(0)
      eirFuncTempCurve.setMaximumValueofy(50)
      # create eirFuncPlrCurve
      eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
      eirFuncPlrCurve.setCoefficient1Constant(4.19E-02)
      eirFuncPlrCurve.setCoefficient2x(6.25E-01)
      eirFuncPlrCurve.setCoefficient3xPOW2(3.23E-01)
      eirFuncPlrCurve.setMinimumValueofx(0)
      eirFuncPlrCurve.setMaximumValueofx(1.2)
      # construct chiller
      chiller = OpenStudio::Model::ChillerElectricEIR.new(model, clgCapFuncTempCurve, eirFuncTempCurve, eirFuncPlrCurve)
      chiller.setReferenceCOP(2.93)
      chiller.setCondenserType('AirCooled')
      chiller.setChillerFlowMode('ConstantFlow')
    end
    # create a scheduled setpoint manager
    setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, chilled_water_setpoint_schedule)
    # create a supply bypass pipe
    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a supply outlet pipe
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand bypass pipe
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand inlet pipe
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand outlet pipe
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # connect components to plant loop
    # supply side components
    chilled_water_plant.addSupplyBranchForComponent(chiller)
    chilled_water_plant.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(chilled_water_plant.supplyInletNode)
    pipe_supply_outlet.addToNode(chilled_water_plant.supplyOutletNode)
    setpoint_manager_scheduled.addToNode(chilled_water_plant.supplyOutletNode)
    # demand side components (water coils are added as they are added to airloops and ZoneHVAC)
    chilled_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(chilled_water_plant.demandInletNode)
    pipe_demand_outlet.addToNode(chilled_water_plant.demandOutletNode)

    # pass back chilled water plant
    result = chilled_water_plant
    return result
  end

  def self.createCondenserLoop(model, runner, options)
    condenserLoops = {}

    # check for water-cooled chillers
    waterCooledChiller = false
    model.getChillerElectricEIRs.sort.each do |chiller|
      next if waterCooledChiller == true
      if chiller.condenserType == 'WaterCooled'
        waterCooledChiller = true
      end
    end
    # create condenser loop for water-cooled chillers
    if waterCooledChiller
      # create condenser loop for water-cooled chiller(s)
      condenser_loop = OpenStudio::Model::PlantLoop.new(model)
      condenser_loop.setName('AEDG Condenser Loop')
      condenser_loop.setMaximumLoopTemperature(80)
      condenser_loop.setMinimumLoopTemperature(5)
      loop_sizing = condenser_loop.sizingPlant
      loop_sizing.setLoopType('Condenser')
      loop_sizing.setDesignLoopExitTemperature(29.4)
      loop_sizing.setLoopDesignTemperatureDifference(5.6)
      # create a pump
      pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      pump.setRatedPumpHead(134508) # Pa
      pump.setMotorEfficiency(0.9)
      pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
      pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
      pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
      # create a cooling tower
      tower = OpenStudio::Model::CoolingTowerVariableSpeed.new(model)
      # create a supply bypass pipe
      pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a supply outlet pipe
      pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a demand bypass pipe
      pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a demand inlet pipe
      pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a demand outlet pipe
      pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a setpoint manager
      setpoint_manager_follow_oa = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
      setpoint_manager_follow_oa.setOffsetTemperatureDifference(0)
      setpoint_manager_follow_oa.setMaximumSetpointTemperature(80)
      setpoint_manager_follow_oa.setMinimumSetpointTemperature(5)
      # connect components to plant loop
      # supply side components
      condenser_loop.addSupplyBranchForComponent(tower)
      condenser_loop.addSupplyBranchForComponent(pipe_supply_bypass)
      pump.addToNode(condenser_loop.supplyInletNode)
      pipe_supply_outlet.addToNode(condenser_loop.supplyOutletNode)
      setpoint_manager_follow_oa.addToNode(condenser_loop.supplyOutletNode)
      # demand side components
      model.getChillerElectricEIRs.sort.each do |chiller|
        if chiller.condenserType == 'WaterCooled' # works only if chillers not already connected to condenser loop(s)
          condenser_loop.addDemandBranchForComponent(chiller)
        end
      end
      condenser_loop.addDemandBranchForComponent(pipe_demand_bypass)
      pipe_demand_inlet.addToNode(condenser_loop.demandInletNode)
      pipe_demand_outlet.addToNode(condenser_loop.demandOutletNode)
      condenserLoops['condenser_loop'] = condenser_loop
    end
    if options['zoneHVAC'].include? 'GSHP'
      # create condenser loop for heat pumps
      condenser_loop = OpenStudio::Model::PlantLoop.new(model)
      condenser_loop.setName('AEDG Heat Pump Loop')
      condenser_loop.setMaximumLoopTemperature(80)
      condenser_loop.setMinimumLoopTemperature(1)
      loop_sizing = condenser_loop.sizingPlant
      loop_sizing.setLoopType('Condenser')
      if options['zoneHVAC'] == 'GSHP'
        loop_sizing.setDesignLoopExitTemperature(21)
        loop_sizing.setLoopDesignTemperatureDifference(5)
      elsif options['zoneHVAC'] == 'WSHP'
        loop_sizing.setDesignLoopExitTemperature(30) # PNNL
        loop_sizing.setLoopDesignTemperatureDifference(20) # PNNL
      end
      # create a pump
      pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      pump.setRatedPumpHead(134508) # Pa
      pump.setMotorEfficiency(0.9)
      pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
      pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
      pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
      # create a supply bypass pipe
      pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a supply outlet pipe
      pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a demand bypass pipe
      pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a demand inlet pipe
      pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
      # create a demand outlet pipe
      pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
      # create setpoint managers
      setpoint_manager_scheduled_loop = OpenStudio::Model::SetpointManagerScheduled.new(model, options['loop_setpoint_schedule'])
      setpoint_manager_scheduled_cooling = OpenStudio::Model::SetpointManagerScheduled.new(model, options['cooling_setpoint_schedule'])
      setpoint_manager_scheduled_heating = OpenStudio::Model::SetpointManagerScheduled.new(model, options['heating_setpoint_schedule'])
      # connect components to plant loop
      # supply side components
      condenser_loop.addSupplyBranchForComponent(pipe_supply_bypass)
      pump.addToNode(condenser_loop.supplyInletNode)
      pipe_supply_outlet.addToNode(condenser_loop.supplyOutletNode)
      setpoint_manager_scheduled_loop.addToNode(condenser_loop.supplyOutletNode)
      # demand side components
      condenser_loop.addDemandBranchForComponent(pipe_demand_bypass)
      pipe_demand_inlet.addToNode(condenser_loop.demandInletNode)
      pipe_demand_outlet.addToNode(condenser_loop.demandOutletNode)
      # add additional components according to specific system type
      if options['zoneHVAC'] == 'GSHP'
        # add district cooling and heating to supply side
        district_cooling = OpenStudio::Model::DistrictCooling.new(model)
        district_cooling.setNominalCapacity(1000000000000) # large number; no autosizing
        condenser_loop.addSupplyBranchForComponent(district_cooling)
        setpoint_manager_scheduled_cooling.addToNode(district_cooling.outletModelObject.get.to_Node.get)
        district_heating = OpenStudio::Model::DistrictHeating.new(model)
        district_heating.setNominalCapacity(1000000000000) # large number; no autosizing
        district_heating.addToNode(district_cooling.outletModelObject.get.to_Node.get)
        setpoint_manager_scheduled_heating.addToNode(district_heating.outletModelObject.get.to_Node.get)
        # add heat pumps to demand side after they get created
      elsif options['zoneHVAC'] == 'WSHP'
        # add a boiler and cooling tower to supply side
        # create a boiler
        boiler = OpenStudio::Model::BoilerHotWater.new(model)
        boiler.setNominalThermalEfficiency(0.9)
        condenser_loop.addSupplyBranchForComponent(boiler)
        setpoint_manager_scheduled_heating.addToNode(boiler.outletModelObject.get.to_Node.get)
        # create a cooling tower
        tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(model)
        tower.addToNode(boiler.outletModelObject.get.to_Node.get)
        setpoint_manager_scheduled_cooling.addToNode(tower.outletModelObject.get.to_Node.get)
      end
      condenserLoops['heat_pump_loop'] = condenser_loop
    end

    # pass back condenser loop(s)
    result = condenserLoops
    return result
  end

  def self.createPrimaryAirLoops(model, runner, options)
    primary_airloops = []
    # create primary airloop for each story
    assignedThermalZones = []
    model.getBuildingStorys.sort.each do |building_story|
      # ML stories need to be reordered from the ground up
      thermalZonesToAdd = []
      building_story.spaces.each do |space|
        # make sure spaces are assigned to thermal zones
        # otherwise might want to send a warning
        if space.thermalZone
          thermal_zone = space.thermalZone.get
          # grab primary zones
          if options['zonesPrimary'].include? thermal_zone
            # make sure zone was not already assigned to another air loop
            unless assignedThermalZones.include? thermal_zone
              # make sure thermal zones are not duplicated (spaces can share thermal zones)
              unless thermalZonesToAdd.include? thermal_zone
                thermalZonesToAdd << thermal_zone
              end
            end
          end
        end
      end
      # make sure thermal zones don't get added to more than one air loop
      assignedThermalZones << thermalZonesToAdd

      # create new air loop if story contains primary zones
      unless thermalZonesToAdd.empty?
        airloop_primary = OpenStudio::Model::AirLoopHVAC.new(model)
        airloop_primary.setName("AEDG Air Loop HVAC #{building_story.name}")
        # modify system sizing properties
        sizing_system = airloop_primary.sizingSystem
        # set central heating and cooling temperatures for sizing
        sizing_system.setCentralCoolingDesignSupplyAirTemperature(12.8)
        sizing_system.setCentralHeatingDesignSupplyAirTemperature(40) # ML OS default is 16.7
        # load specification
        sizing_system.setSystemOutdoorAirMethod('VentilationRateProcedure') # ML OS default is ZoneSum
        if options['primaryHVAC']['doas']
          sizing_system.setTypeofLoadtoSizeOn('VentilationRequirement') # DOAS
          sizing_system.setAllOutdoorAirinCooling(true) # DOAS
          sizing_system.setAllOutdoorAirinHeating(true) # DOAS
        else
          sizing_system.setTypeofLoadtoSizeOn('Sensible') # VAV
          sizing_system.setAllOutdoorAirinCooling(false) # VAV
          sizing_system.setAllOutdoorAirinHeating(false) # VAV
        end

        air_loop_comps = []
        # set availability schedule
        airloop_primary.setAvailabilitySchedule(options['hvac_schedule'])
        # create air loop fan
        if options['primaryHVAC']['fan'] == 'Variable'
          # create variable speed fan and set system sizing accordingly
          sizing_system.setCentralHeatingMaximumSystemAirFlowRatio(0.3) # DCV
          # variable speed fan
          fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
          fan.setFanEfficiency(0.69)
          fan.setPressureRise(1125) # Pa
          fan.autosizeMaximumFlowRate
          fan.setFanPowerMinimumFlowFraction(0.6)
          fan.setMotorEfficiency(0.9)
          fan.setMotorInAirstreamFraction(1.0)
          air_loop_comps << fan
        else
          sizing_system.setCentralHeatingMaximumSystemAirFlowRatio(1.0) # No DCV
          # constant speed fan
          fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
          fan.setFanEfficiency(0.6)
          fan.setPressureRise(500) # Pa
          fan.autosizeMaximumFlowRate
          fan.setMotorEfficiency(0.9)
          fan.setMotorInAirstreamFraction(1.0)
          air_loop_comps << fan
        end
        # create heating coil
        if options['primaryHVAC']['heat'] == 'Water'
          # water coil
          heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
          air_loop_comps << heating_coil
        else
          # gas coil
          heating_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
          air_loop_comps << heating_coil
        end
        # create cooling coil
        if options['primaryHVAC']['cool'] == 'Water'
          # water coil
          cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
          air_loop_comps << cooling_coil
        elsif options['primaryHVAC']['cool'] == 'SingleDX'
          # single speed DX coil
          # create cooling coil
          # create clgCapFuncTempCurve
          clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgCapFuncTempCurve.setCoefficient1Constant(0.42415)
          clgCapFuncTempCurve.setCoefficient2x(0.04426)
          clgCapFuncTempCurve.setCoefficient3xPOW2(-0.00042)
          clgCapFuncTempCurve.setCoefficient4y(0.00333)
          clgCapFuncTempCurve.setCoefficient5yPOW2(-0.00008)
          clgCapFuncTempCurve.setCoefficient6xTIMESY(-0.00021)
          clgCapFuncTempCurve.setMinimumValueofx(17)
          clgCapFuncTempCurve.setMaximumValueofx(22)
          clgCapFuncTempCurve.setMinimumValueofy(13)
          clgCapFuncTempCurve.setMaximumValueofy(46)
          # create clgCapFuncFlowFracCurve
          clgCapFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgCapFuncFlowFracCurve.setCoefficient1Constant(0.77136)
          clgCapFuncFlowFracCurve.setCoefficient2x(0.34053)
          clgCapFuncFlowFracCurve.setCoefficient3xPOW2(-0.11088)
          clgCapFuncFlowFracCurve.setMinimumValueofx(0.75918)
          clgCapFuncFlowFracCurve.setMaximumValueofx(1.13877)
          # create clgEirFuncTempCurve
          clgEirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgEirFuncTempCurve.setCoefficient1Constant(1.23649)
          clgEirFuncTempCurve.setCoefficient2x(-0.02431)
          clgEirFuncTempCurve.setCoefficient3xPOW2(0.00057)
          clgEirFuncTempCurve.setCoefficient4y(-0.01434)
          clgEirFuncTempCurve.setCoefficient5yPOW2(0.00063)
          clgEirFuncTempCurve.setCoefficient6xTIMESY(-0.00038)
          clgEirFuncTempCurve.setMinimumValueofx(17)
          clgEirFuncTempCurve.setMaximumValueofx(22)
          clgEirFuncTempCurve.setMinimumValueofy(13)
          clgEirFuncTempCurve.setMaximumValueofy(46)
          # create clgEirFuncFlowFracCurve
          clgEirFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgEirFuncFlowFracCurve.setCoefficient1Constant(1.20550)
          clgEirFuncFlowFracCurve.setCoefficient2x(-0.32953)
          clgEirFuncFlowFracCurve.setCoefficient3xPOW2(0.12308)
          clgEirFuncFlowFracCurve.setMinimumValueofx(0.75918)
          clgEirFuncFlowFracCurve.setMaximumValueofx(1.13877)
          # create clgPlrCurve
          clgPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgPlrCurve.setCoefficient1Constant(0.77100)
          clgPlrCurve.setCoefficient2x(0.22900)
          clgPlrCurve.setCoefficient3xPOW2(0.0)
          clgPlrCurve.setMinimumValueofx(0.0)
          clgPlrCurve.setMaximumValueofx(1.0)
          # cooling coil
          cooling_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                         model.alwaysOnDiscreteSchedule,
                                                                         clgCapFuncTempCurve,
                                                                         clgCapFuncFlowFracCurve,
                                                                         clgEirFuncTempCurve,
                                                                         clgEirFuncFlowFracCurve,
                                                                         clgPlrCurve)
          cooling_coil.setRatedCOP(OpenStudio::OptionalDouble.new(4))
          air_loop_comps << cooling_coil
        else
          # two speed DX coil (PNNL curves)
          # create cooling coil
          # create clgCapFuncTempCurve
          clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgCapFuncTempCurve.setCoefficient1Constant(1.39072)
          clgCapFuncTempCurve.setCoefficient2x(-0.0529058)
          clgCapFuncTempCurve.setCoefficient3xPOW2(0.0018423)
          clgCapFuncTempCurve.setCoefficient4y(0.00058267)
          clgCapFuncTempCurve.setCoefficient5yPOW2(-0.000186814)
          clgCapFuncTempCurve.setCoefficient6xTIMESY(0.000265159)
          clgCapFuncTempCurve.setMinimumValueofx(16.5556)
          clgCapFuncTempCurve.setMaximumValueofx(22.1111)
          clgCapFuncTempCurve.setMinimumValueofy(23.7778)
          clgCapFuncTempCurve.setMaximumValueofy(47.66)
          # create clgCapFuncFlowFracCurve
          clgCapFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgCapFuncFlowFracCurve.setCoefficient1Constant(0.718954)
          clgCapFuncFlowFracCurve.setCoefficient2x(0.435436)
          clgCapFuncFlowFracCurve.setCoefficient3xPOW2(-0.154193)
          clgCapFuncFlowFracCurve.setMinimumValueofx(0.75)
          clgCapFuncFlowFracCurve.setMaximumValueofx(1.25)
          # create clgEirFuncTempCurve
          clgEirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgEirFuncTempCurve.setCoefficient1Constant(-0.536161)
          clgEirFuncTempCurve.setCoefficient2x(0.105138)
          clgEirFuncTempCurve.setCoefficient3xPOW2(-0.00172659)
          clgEirFuncTempCurve.setCoefficient4y(0.0149848)
          clgEirFuncTempCurve.setCoefficient5yPOW2(0.000659948)
          clgEirFuncTempCurve.setCoefficient6xTIMESY(-0.0017385)
          clgEirFuncTempCurve.setMinimumValueofx(16.5556)
          clgEirFuncTempCurve.setMaximumValueofx(22.1111)
          clgEirFuncTempCurve.setMinimumValueofy(23.7778)
          clgEirFuncTempCurve.setMaximumValueofy(47.66)
          # create clgEirFuncFlowFracCurve
          clgEirFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgEirFuncFlowFracCurve.setCoefficient1Constant(1.19525)
          clgEirFuncFlowFracCurve.setCoefficient2x(-0.306138)
          clgEirFuncFlowFracCurve.setCoefficient3xPOW2(0.110973)
          clgEirFuncFlowFracCurve.setMinimumValueofx(0.75)
          clgEirFuncFlowFracCurve.setMaximumValueofx(1.25)
          # create clgPlrCurve
          clgPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgPlrCurve.setCoefficient1Constant(0.77100)
          clgPlrCurve.setCoefficient2x(0.22900)
          clgPlrCurve.setCoefficient3xPOW2(0.0)
          clgPlrCurve.setMinimumValueofx(0.0)
          clgPlrCurve.setMaximumValueofx(1.0)
          # cooling coil
          cooling_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                                                                      model.alwaysOnDiscreteSchedule,
                                                                      clgCapFuncTempCurve,
                                                                      clgCapFuncFlowFracCurve,
                                                                      clgEirFuncTempCurve,
                                                                      clgEirFuncFlowFracCurve,
                                                                      clgPlrCurve,
                                                                      clgCapFuncTempCurve,
                                                                      clgEirFuncTempCurve)
          cooling_coil.setRatedHighSpeedCOP(4)
          cooling_coil.setRatedLowSpeedCOP(4)
          air_loop_comps << cooling_coil
        end
        unless options['zoneHVAC'] == 'DualDuct'
          # create controller outdoor air
          controller_OA = OpenStudio::Model::ControllerOutdoorAir.new(model)
          controller_OA.autosizeMinimumOutdoorAirFlowRate
          controller_OA.autosizeMaximumOutdoorAirFlowRate
          # create ventilation schedules and assign to OA controller
          if options['primaryHVAC']['doas']
            controller_OA.setMinimumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)
            controller_OA.setMaximumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)
          else
            # multizone VAV that ventilates
            controller_OA.setMaximumFractionofOutdoorAirSchedule(options['ventilation_schedule'])
            controller_OA.setEconomizerControlType('DifferentialEnthalpy')
            # add night cycling (ML would people actually do this for a VAV system?))
            airloop_primary.setNightCycleControlType('CycleOnAny') # ML Does this work with variable speed fans?
          end
          controller_OA.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')
          # create outdoor air system
          system_OA = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, controller_OA)
          air_loop_comps << system_OA
          # create ERV
          heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
          heat_exchanger.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
          sensible_eff = 0.75
          latent_eff = 0.69
          heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(sensible_eff)
          heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(sensible_eff)
          heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(sensible_eff)
          heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(sensible_eff)
          heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(latent_eff)
          heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(latent_eff)
          heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(latent_eff)
          heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(latent_eff)
          heat_exchanger.setFrostControlType('ExhaustOnly')
          heat_exchanger.setThresholdTemperature(-12.2)
          heat_exchanger.setInitialDefrostTimeFraction(0.1670)
          heat_exchanger.setRateofDefrostTimeFractionIncrease(0.0240)
          heat_exchanger.setEconomizerLockout(false)
        end
        # create scheduled setpoint manager for airloop
        if options['primaryHVAC']['doas'] || (options['zoneHVAC'] == 'DualDuct')
          # DOAS or VAV for cooling and not ventilation
          setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, options['primary_sat_schedule'])
        else
          # VAV for cooling and ventilation
          setpoint_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
          setpoint_manager.setSetpointatOutdoorLowTemperature(15.6)
          setpoint_manager.setOutdoorLowTemperature(14.4)
          setpoint_manager.setSetpointatOutdoorHighTemperature(12.8)
          setpoint_manager.setOutdoorHighTemperature(21.1)
        end
        # connect components to airloop
        # find the supply inlet node of the airloop
        airloop_supply_inlet = airloop_primary.supplyInletNode
        # add the components to the airloop
        air_loop_comps.each do |comp|
          comp.addToNode(airloop_supply_inlet)
          if comp.to_CoilHeatingWater.is_initialized
            options['hot_water_plant'].addDemandBranchForComponent(comp)
          elsif comp.to_CoilCoolingWater.is_initialized
            options['chilled_water_plant'].addDemandBranchForComponent(comp)
          end
        end
        # add erv to outdoor air system
        unless options['zoneHVAC'] == 'DualDuct'
          heat_exchanger.addToNode(system_OA.outboardOANode.get)
        end
        # add setpoint manager to supply equipment outlet node
        setpoint_manager.addToNode(airloop_primary.supplyOutletNode)
        # add thermal zones to airloop
        thermalZonesToAdd.each do |zone|
          # make an air terminal for the zone
          if options['primaryHVAC']['fan'] == 'Variable'
            air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
          else
            air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
          end
          # attach new terminal to the zone and to the airloop
          airloop_primary.addBranchForZone(zone, air_terminal.to_StraightComponent)
        end
        primary_airloops << airloop_primary
      end
    end

    # pass back primary airloops
    result = primary_airloops
    return result
  end

  def self.createSecondaryAirLoops(model, runner, options)
    secondary_airloops = []
    # create secondary airloop for each secondary zone
    model.getThermalZones.sort.each do |zone|
      if options['zonesSecondary'].include? zone
        # create secondary airloop
        airloop_secondary = OpenStudio::Model::AirLoopHVAC.new(model)
        airloop_secondary.setName("AEDG Air Loop HVAC #{zone.name}")
        # modify system sizing properties
        sizing_system = airloop_secondary.sizingSystem
        # set central heating and cooling temperatures for sizing
        sizing_system.setCentralCoolingDesignSupplyAirTemperature(12.8)
        sizing_system.setCentralHeatingDesignSupplyAirTemperature(40) # ML OS default is 16.7
        # load specification
        sizing_system.setSystemOutdoorAirMethod('VentilationRateProcedure') # ML OS default is ZoneSum
        sizing_system.setTypeofLoadtoSizeOn('Sensible') # PSZ
        sizing_system.setAllOutdoorAirinCooling(false) # PSZ
        sizing_system.setAllOutdoorAirinHeating(false) # PSZ
        sizing_system.setCentralHeatingMaximumSystemAirFlowRatio(1.0) # Constant volume fan
        air_loop_comps = []
        # set availability schedule (HVAC operation schedule)
        airloop_secondary.setAvailabilitySchedule(options['hvac_schedule'])
        if options['secondaryHVAC']['fan'] == 'Variable'
          # create variable speed fan and set system sizing accordingly
          sizing_system.setCentralHeatingMaximumSystemAirFlowRatio(0.3) # DCV
          # variable speed fan
          fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
          fan.setFanEfficiency(0.69)
          fan.setPressureRise(1125) # Pa
          fan.autosizeMaximumFlowRate
          fan.setFanPowerMinimumFlowFraction(0.6)
          fan.setMotorEfficiency(0.9)
          fan.setMotorInAirstreamFraction(1.0)
          air_loop_comps << fan
        else
          sizing_system.setCentralHeatingMaximumSystemAirFlowRatio(1.0) # No DCV
          # constant speed fan
          fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
          fan.setFanEfficiency(0.6)
          fan.setPressureRise(500) # Pa
          fan.autosizeMaximumFlowRate
          fan.setMotorEfficiency(0.9)
          fan.setMotorInAirstreamFraction(1.0)
          air_loop_comps << fan
        end
        # create cooling coil
        if options['secondaryHVAC']['cool'] == 'Water'
          # water coil
          cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
          air_loop_comps << cooling_coil
        elsif options['secondaryHVAC']['cool'] == 'SingleDX'
          # single speed DX coil
          # create cooling coil
          # create clgCapFuncTempCurve
          clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgCapFuncTempCurve.setCoefficient1Constant(0.42415)
          clgCapFuncTempCurve.setCoefficient2x(0.04426)
          clgCapFuncTempCurve.setCoefficient3xPOW2(-0.00042)
          clgCapFuncTempCurve.setCoefficient4y(0.00333)
          clgCapFuncTempCurve.setCoefficient5yPOW2(-0.00008)
          clgCapFuncTempCurve.setCoefficient6xTIMESY(-0.00021)
          clgCapFuncTempCurve.setMinimumValueofx(17)
          clgCapFuncTempCurve.setMaximumValueofx(22)
          clgCapFuncTempCurve.setMinimumValueofy(13)
          clgCapFuncTempCurve.setMaximumValueofy(46)
          # create clgCapFuncFlowFracCurve
          clgCapFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgCapFuncFlowFracCurve.setCoefficient1Constant(0.77136)
          clgCapFuncFlowFracCurve.setCoefficient2x(0.34053)
          clgCapFuncFlowFracCurve.setCoefficient3xPOW2(-0.11088)
          clgCapFuncFlowFracCurve.setMinimumValueofx(0.75918)
          clgCapFuncFlowFracCurve.setMaximumValueofx(1.13877)
          # create clgEirFuncTempCurve
          clgEirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgEirFuncTempCurve.setCoefficient1Constant(1.23649)
          clgEirFuncTempCurve.setCoefficient2x(-0.02431)
          clgEirFuncTempCurve.setCoefficient3xPOW2(0.00057)
          clgEirFuncTempCurve.setCoefficient4y(-0.01434)
          clgEirFuncTempCurve.setCoefficient5yPOW2(0.00063)
          clgEirFuncTempCurve.setCoefficient6xTIMESY(-0.00038)
          clgEirFuncTempCurve.setMinimumValueofx(17)
          clgEirFuncTempCurve.setMaximumValueofx(22)
          clgEirFuncTempCurve.setMinimumValueofy(13)
          clgEirFuncTempCurve.setMaximumValueofy(46)
          # create clgEirFuncFlowFracCurve
          clgEirFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgEirFuncFlowFracCurve.setCoefficient1Constant(1.20550)
          clgEirFuncFlowFracCurve.setCoefficient2x(-0.32953)
          clgEirFuncFlowFracCurve.setCoefficient3xPOW2(0.12308)
          clgEirFuncFlowFracCurve.setMinimumValueofx(0.75918)
          clgEirFuncFlowFracCurve.setMaximumValueofx(1.13877)
          # create clgPlrCurve
          clgPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgPlrCurve.setCoefficient1Constant(0.77100)
          clgPlrCurve.setCoefficient2x(0.22900)
          clgPlrCurve.setCoefficient3xPOW2(0.0)
          clgPlrCurve.setMinimumValueofx(0.0)
          clgPlrCurve.setMaximumValueofx(1.0)
          # cooling coil
          cooling_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                         model.alwaysOnDiscreteSchedule,
                                                                         clgCapFuncTempCurve,
                                                                         clgCapFuncFlowFracCurve,
                                                                         clgEirFuncTempCurve,
                                                                         clgEirFuncFlowFracCurve,
                                                                         clgPlrCurve)
          cooling_coil.setRatedCOP(OpenStudio::OptionalDouble.new(4))
          air_loop_comps << cooling_coil
        else
          # two speed DX coil (PNNL curves)
          # create cooling coil
          # create clgCapFuncTempCurve
          clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgCapFuncTempCurve.setCoefficient1Constant(1.39072)
          clgCapFuncTempCurve.setCoefficient2x(-0.0529058)
          clgCapFuncTempCurve.setCoefficient3xPOW2(0.0018423)
          clgCapFuncTempCurve.setCoefficient4y(0.00058267)
          clgCapFuncTempCurve.setCoefficient5yPOW2(-0.000186814)
          clgCapFuncTempCurve.setCoefficient6xTIMESY(0.000265159)
          clgCapFuncTempCurve.setMinimumValueofx(16.5556)
          clgCapFuncTempCurve.setMaximumValueofx(22.1111)
          clgCapFuncTempCurve.setMinimumValueofy(23.7778)
          clgCapFuncTempCurve.setMaximumValueofy(47.66)
          # create clgCapFuncFlowFracCurve
          clgCapFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgCapFuncFlowFracCurve.setCoefficient1Constant(0.718954)
          clgCapFuncFlowFracCurve.setCoefficient2x(0.435436)
          clgCapFuncFlowFracCurve.setCoefficient3xPOW2(-0.154193)
          clgCapFuncFlowFracCurve.setMinimumValueofx(0.75)
          clgCapFuncFlowFracCurve.setMaximumValueofx(1.25)
          # create clgEirFuncTempCurve
          clgEirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgEirFuncTempCurve.setCoefficient1Constant(-0.536161)
          clgEirFuncTempCurve.setCoefficient2x(0.105138)
          clgEirFuncTempCurve.setCoefficient3xPOW2(-0.00172659)
          clgEirFuncTempCurve.setCoefficient4y(0.0149848)
          clgEirFuncTempCurve.setCoefficient5yPOW2(0.000659948)
          clgEirFuncTempCurve.setCoefficient6xTIMESY(-0.0017385)
          clgEirFuncTempCurve.setMinimumValueofx(16.5556)
          clgEirFuncTempCurve.setMaximumValueofx(22.1111)
          clgEirFuncTempCurve.setMinimumValueofy(23.7778)
          clgEirFuncTempCurve.setMaximumValueofy(47.66)
          # create clgEirFuncFlowFracCurve
          clgEirFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgEirFuncFlowFracCurve.setCoefficient1Constant(1.19525)
          clgEirFuncFlowFracCurve.setCoefficient2x(-0.306138)
          clgEirFuncFlowFracCurve.setCoefficient3xPOW2(0.110973)
          clgEirFuncFlowFracCurve.setMinimumValueofx(0.75)
          clgEirFuncFlowFracCurve.setMaximumValueofx(1.25)
          # create clgPlrCurve
          clgPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
          clgPlrCurve.setCoefficient1Constant(0.77100)
          clgPlrCurve.setCoefficient2x(0.22900)
          clgPlrCurve.setCoefficient3xPOW2(0.0)
          clgPlrCurve.setMinimumValueofx(0.0)
          clgPlrCurve.setMaximumValueofx(1.0)
          # cooling coil
          cooling_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                                                                      model.alwaysOnDiscreteSchedule,
                                                                      clgCapFuncTempCurve,
                                                                      clgCapFuncFlowFracCurve,
                                                                      clgEirFuncTempCurve,
                                                                      clgEirFuncFlowFracCurve,
                                                                      clgPlrCurve,
                                                                      clgCapFuncTempCurve,
                                                                      clgEirFuncTempCurve)
          cooling_coil.setRatedHighSpeedCOP(4)
          cooling_coil.setRatedLowSpeedCOP(4)
          air_loop_comps << cooling_coil
        end
        if options['secondaryHVAC']['heat'] == 'Water'
          # water coil
          heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
          air_loop_comps << heating_coil
        else
          # gas coil
          heating_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
          air_loop_comps << heating_coil
        end
        # create controller outdoor air
        controller_OA = OpenStudio::Model::ControllerOutdoorAir.new(model)
        controller_OA.autosizeMinimumOutdoorAirFlowRate
        controller_OA.autosizeMaximumOutdoorAirFlowRate
        controller_OA.setEconomizerControlType('DifferentialEnthalpy')
        controller_OA.setMaximumFractionofOutdoorAirSchedule(options['ventilation_schedule'])
        controller_OA.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')
        # create outdoor air system
        system_OA = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, controller_OA)
        air_loop_comps << system_OA
        # create ERV
        heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
        heat_exchanger.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
        sensible_eff = 0.75
        latent_eff = 0.69
        heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(sensible_eff)
        heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(sensible_eff)
        heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(sensible_eff)
        heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(sensible_eff)
        heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(latent_eff)
        heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(latent_eff)
        heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(latent_eff)
        heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(latent_eff)
        heat_exchanger.setFrostControlType('ExhaustOnly')
        heat_exchanger.setThresholdTemperature(-12.2)
        heat_exchanger.setInitialDefrostTimeFraction(0.1670)
        heat_exchanger.setRateofDefrostTimeFractionIncrease(0.0240)
        heat_exchanger.setEconomizerLockout(false)
        # create setpoint manager for airloop
        setpoint_manager = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
        setpoint_manager.setMinimumSupplyAirTemperature(10)
        setpoint_manager.setMaximumSupplyAirTemperature(50)
        setpoint_manager.setControlZone(zone)
        # connect components to airloop
        # find the supply inlet node of the airloop
        airloop_supply_inlet = airloop_secondary.supplyInletNode
        # add the components to the airloop
        air_loop_comps.each do |comp|
          comp.addToNode(airloop_supply_inlet)
          if comp.to_CoilHeatingWater.is_initialized
            options['hot_water_plant'].addDemandBranchForComponent(comp)
          elsif comp.to_CoilCoolingWater.is_initialized
            options['chilled_water_plant'].addDemandBranchForComponent(comp)
          end
        end
        # add erv to outdoor air system
        heat_exchanger.addToNode(system_OA.outboardOANode.get)
        # add setpoint manager to supply equipment outlet node
        setpoint_manager.addToNode(airloop_secondary.supplyOutletNode)
        # add thermal zone to airloop
        if options['secondaryHVAC']['fan'] == 'Variable'
          air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
        else
          air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        end
        # attach new terminal to the zone and to the airloop
        airloop_secondary.addBranchForZone(zone, air_terminal.to_StraightComponent)
        # add night cycling
        airloop_secondary.setNightCycleControlType('CycleOnAny') # ML Does this work with variable speed fans?
        secondary_airloops << airloop_secondary
      end
    end

    # pass back secondary airloops
    result = secondary_airloops
    return result
  end

  def self.createPrimaryZoneEquipment(model, runner, options)
    model.getThermalZones.sort.each do |zone|
      if options['zonesPrimary'].include? zone
        if options['zoneHVAC'] == 'FanCoil'
          # create fan coil
          # create fan
          fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
          fan.setFanEfficiency(0.5)
          fan.setPressureRise(75) # Pa
          fan.autosizeMaximumFlowRate
          fan.setMotorEfficiency(0.9)
          fan.setMotorInAirstreamFraction(1.0)
          # create cooling coil and connect to chilled water plant
          cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
          options['chilled_water_plant'].addDemandBranchForComponent(cooling_coil)
          # create heating coil and connect to hot water plant
          heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
          options['hot_water_plant'].addDemandBranchForComponent(heating_coil)
          # construct fan coil
          fan_coil = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model,
                                                                    model.alwaysOnDiscreteSchedule,
                                                                    fan,
                                                                    cooling_coil,
                                                                    heating_coil)
          fan_coil.setMaximumOutdoorAirFlowRate(0)
          # add fan coil to thermal zone
          fan_coil.addToThermalZone(zone)
        elsif options['zoneHVAC'].include? 'GSHP'
          # create water source heat pump and attach to heat pump loop
          # create fan
          fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
          fan.setFanEfficiency(0.5)
          fan.setPressureRise(75) # Pa
          fan.autosizeMaximumFlowRate
          fan.setMotorEfficiency(0.9)
          fan.setMotorInAirstreamFraction(1.0)
          # create cooling coil and connect to heat pump loop
          cooling_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model)
          cooling_coil.setRatedCoolingCoefficientofPerformance(6.45)

          curve = OpenStudio::Model::CurveQuadLinear.new(model)
          curve.setName("#{cooling_coil.name}_tot_clg_cap_curve")
          curve.setCoefficient1Constant(-9.149069561)
          curve.setCoefficient2w(10.87814026)
          curve.setCoefficient3x(-1.718780157)
          curve.setCoefficient4y(0.746414818)
          curve.setCoefficient5z(0.0)
          cooling_coil.setTotalCoolingCapacityCurve(curve)

          curve = OpenStudio::Model::CurveQuintLinear.new(model)
          curve.setName("#{cooling_coil.name}_sens_clg_cap_curve")
          curve.setCoefficient1Constant(-5.462690012)
          curve.setCoefficient2v(17.95968138)
          curve.setCoefficient3w(-11.87818402)
          curve.setCoefficient4x(-0.980163419)
          curve.setCoefficient5y(0.767285761)
          curve.setCoefficient6z(0.0)
          cooling_coil.setSensibleCoolingCapacityCurve(curve)

          curve = OpenStudio::Model::CurveQuadLinear.new(model)
          curve.setName("#{cooling_coil.name}_clg_pwr_consu_curve")
          curve.setCoefficient1Constant(-3.205409884)
          curve.setCoefficient2w(-0.976409399)
          curve.setCoefficient3x(3.97892546)
          curve.setCoefficient4y(0.938181818)
          curve.setCoefficient5z(0.0)
          cooling_coil.setCoolingPowerConsumptionCurve(curve)

          options['heat_pump_loop'].addDemandBranchForComponent(cooling_coil)
          # create heating coil and connect to heat pump loop
          heating_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)
          heating_coil.setRatedHeatingCoefficientofPerformance(4.0)

          curve = OpenStudio::Model::CurveQuadLinear.new(model)
          curve.setName("#{heating_coil.name}_htg_cap_curve")
          curve.setCoefficient1Constant(-1.361311959)
          curve.setCoefficient2w(-2.471798046)
          curve.setCoefficient3x(4.173164514)
          curve.setCoefficient4y(0.640757401)
          curve.setCoefficient5z(0.0)
          heating_coil.setHeatingCapacityCurve(curve)

          curve = OpenStudio::Model::CurveQuadLinear.new(model)
          curve.setName("#{heating_coil.name}_htg_pwr_consu_curve")
          curve.setCoefficient1Constant(-2.176941116)
          curve.setCoefficient2w(0.832114286)
          curve.setCoefficient3x(1.570743399)
          curve.setCoefficient4y(0.690793651)
          curve.setCoefficient5z(0.0)
          heating_coil.setHeatingPowerConsumptionCurve(curve)

          options['heat_pump_loop'].addDemandBranchForComponent(heating_coil)
          # create supplemental heating coil
          supplemental_heating_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
          # construct heat pump
          heat_pump = OpenStudio::Model::ZoneHVACWaterToAirHeatPump.new(model,
                                                                        model.alwaysOnDiscreteSchedule,
                                                                        fan,
                                                                        heating_coil,
                                                                        cooling_coil,
                                                                        supplemental_heating_coil)
          heat_pump.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0))
          heat_pump.setOutdoorAirFlowRateDuringCoolingOperation(OpenStudio::OptionalDouble.new(0))
          heat_pump.setOutdoorAirFlowRateDuringHeatingOperation(OpenStudio::OptionalDouble.new(0))
          heat_pump.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0))
          # add heat pump to thermal zone
          heat_pump.addToThermalZone(zone)
        elsif options['zoneHVAC'] == 'Baseboard'
          # create baseboard heater add add to thermal zone and hot water loop
          baseboard_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
          baseboard_heater = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule, baseboard_coil)
          baseboard_heater.addToThermalZone(zone)
          options['hot_water_plant'].addDemandBranchForComponent(baseboard_coil)
        elsif options['zoneHVAC'] == 'Radiant'
          # create low temperature radiant object and add to thermal zone and radiant plant loops
          # create hot water coil and attach to radiant hot water loop
          heating_coil = OpenStudio::Model::CoilHeatingLowTempRadiantVarFlow.new(model, options['mean_radiant_heating_setpoint_schedule'])
          options['radiant_hot_water_plant'].addDemandBranchForComponent(heating_coil)
          # create chilled water coil and attach to radiant chilled water loop
          cooling_coil = OpenStudio::Model::CoilCoolingLowTempRadiantVarFlow.new(model, options['mean_radiant_cooling_setpoint_schedule'])
          options['radiant_chilled_water_plant'].addDemandBranchForComponent(cooling_coil)
          low_temp_radiant = OpenStudio::Model::ZoneHVACLowTempRadiantVarFlow.new(model,
                                                                                  model.alwaysOnDiscreteSchedule,
                                                                                  heating_coil,
                                                                                  cooling_coil)
          low_temp_radiant.setRadiantSurfaceType('Floors')
          low_temp_radiant.setHydronicTubingInsideDiameter(0.012)
          low_temp_radiant.setTemperatureControlType('MeanRadiantTemperature')
          low_temp_radiant.addToThermalZone(zone)
          # create radiant floor construction and substitute for existing floor (interior or exterior) constructions
          # create materials for radiant floor construction
          layers = []
          # ignore layer below insulation, which will depend on boundary condition
          layers << rigid_insulation_1in = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'Rough', 0.0254, 0.02, 56.06, 1210)
          layers << concrete_2in = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0508, 2.31, 2322, 832)
          layers << concrete_2in
          # create radiant floor construction from materials
          radiant_floor = OpenStudio::Model::ConstructionWithInternalSource.new(layers)
          radiant_floor.setSourcePresentAfterLayerNumber(2)
          radiant_floor.setSourcePresentAfterLayerNumber(2)
          # assign radiant construction to zone floor
          zone.spaces.each do |space|
            space.surfaces.each do |surface|
              if surface.surfaceType == 'Floor'
                surface.setConstruction(radiant_floor)
              end
            end
          end
        elsif options['zoneHVAC'] == 'DualDuct'
          # create baseboard heater add add to thermal zone and hot water loop
          baseboard_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
          baseboard_heater = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule, baseboard_coil)
          baseboard_heater.addToThermalZone(zone)
          options['hot_water_plant'].addDemandBranchForComponent(baseboard_coil)
          # create fan coil (to mimic functionality of DOAS)
          # variable speed fan
          fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
          fan.setFanEfficiency(0.69)
          fan.setPressureRise(75) # Pa #ML This number is a guess; zone equipment pretending to be a DOAS
          fan.autosizeMaximumFlowRate
          fan.setFanPowerMinimumFlowFraction(0.6)
          fan.setMotorEfficiency(0.9)
          fan.setMotorInAirstreamFraction(1.0)
          # create chilled water coil and attach to chilled water loop
          cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
          options['chilled_water_plant'].addDemandBranchForComponent(cooling_coil)
          # create hot water coil and attach to hot water loop
          heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
          options['hot_water_plant'].addDemandBranchForComponent(heating_coil)
          # construct fan coil (DOAS) and attach to thermal zone
          fan_coil_doas = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model,
                                                                         options['ventilation_schedule'],
                                                                         fan,
                                                                         cooling_coil,
                                                                         heating_coil)
          fan_coil_doas.setCapacityControlMethod('VariableFanVariableFlow')
          fan_coil_doas.addToThermalZone(zone)
        end
      end
    end
  end

  def self.addDCV(model, runner, options)
    unless options['primary_airloops'].nil?
      options['primary_airloops'].each do |airloop|
        if options['allHVAC']['primary']['fan'] == 'Variable'
          controller_mv = airloop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir.controllerMechanicalVentilation
          controller_mv.setDemandControlledVentilation(true)
          runner.registerInfo("Enabling demand control ventilation for #{airloop.name}")
        end
      end
    end

    unless options['secondary_airloops'].nil?
      options['secondary_airloops'].each do |airloop|
        if options['allHVAC']['secondary']['fan'] == 'Variable'
          controller_mv = airloop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir.controllerMechanicalVentilation
          controller_mv.setDemandControlledVentilation(true)
          runner.registerInfo("Enabling demand control ventilation for #{airloop.name}")
        end
      end
    end
  end

  def self.getSpacesAndSpaceTypesFromThermalZone(zone, runner)
    # set flag
    space_type_hash = {}

    # check if zone has spaces
    if zone.spaces.empty?
      runner.registerWarning("#{zone.name} doesn't have any spaces.")
    else
      # check if all spaces have the same space type
      zone.spaces.each do |space|
        if !space.spaceType.is_initialized
          runner.registerWarning("One or more spaces in #{zone.name} doesn't have a space type assigned.")
          space_type_hash[space] = false
          return space_type
        else
          space_type_hash[space] = space.spaceType.get
        end
      end
    end

    return space_type_hash
  end

  def self.get_or_add_hot_water_loop(model)
    # How water loop
    hw_loop = nil
    model.getLoops.sort.each do |loop|
      if loop.name.to_s == 'Hot Water Loop' # sizingPlant has loopType method to do this better
        hw_loop = loop.to_PlantLoop.get
      end
    end

    if hw_loop.nil?
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      hw_loop.setName('Hot Water Loop')
      hw_sizing_plant = hw_loop.sizingPlant
      hw_sizing_plant.setLoopType('Heating')
      hw_sizing_plant.setDesignLoopExitTemperature(82.0) # TODO: units
      hw_sizing_plant.setLoopDesignTemperatureDifference(11.0)

      hw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

      boiler = OpenStudio::Model::BoilerHotWater.new(model)

      boiler_eff_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      boiler_eff_f_of_temp.setName('Boiler Efficiency')
      boiler_eff_f_of_temp.setCoefficient1Constant(1.0)
      boiler_eff_f_of_temp.setInputUnitTypeforX('Dimensionless')
      boiler_eff_f_of_temp.setInputUnitTypeforY('Dimensionless')
      boiler_eff_f_of_temp.setOutputUnitType('Dimensionless')

      boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_f_of_temp)
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')

      boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      hw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      # Add the components to the hot water loop
      hw_supply_inlet_node = hw_loop.supplyInletNode
      hw_supply_outlet_node = hw_loop.supplyOutletNode
      hw_pump.addToNode(hw_supply_inlet_node)
      hw_loop.addSupplyBranchForComponent(boiler)
      hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
      hw_supply_outlet_pipe.addToNode(hw_supply_outlet_node)

      # Add a setpoint manager to control the
      # hot water to a constant temperature
      hw_t_c = OpenStudio.convert(153, 'F', 'C').get
      hw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      hw_t_sch.setName('HW Temp')
      hw_t_sch.defaultDaySchedule.setName('HW Temp Default')
      hw_t_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hw_t_c)
      hw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hw_t_sch)
      hw_t_stpt_manager.addToNode(hw_supply_outlet_node)

    end

    return hw_loop
  end

  def self.get_or_add_water_cooled_chiller_loops(model)
    # Chilled Water Plant
    # todo - add in logic here that if existing chw_loop is air cooled, replace it with this one.
    chw_loop = nil
    model.getLoops.sort.each do |loop|
      if loop.name.to_s == 'Chilled Water Loop'
        chw_loop = loop.to_PlantLoop.get
      end
    end

    if chw_loop.nil?
      chw_loop = OpenStudio::Model::PlantLoop.new(model)
      chw_loop.setName('Chilled Water Loop')
      chw_sizing_plant = chw_loop.sizingPlant
      chw_sizing_plant.setLoopType('Cooling')
      chw_sizing_plant.setDesignLoopExitTemperature(7.22) # TODO: units
      chw_sizing_plant.setLoopDesignTemperatureDifference(6.67)

      chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp.setCoefficient1Constant(1.0215158)
      clg_cap_f_of_temp.setCoefficient2x(0.037035864)
      clg_cap_f_of_temp.setCoefficient3xPOW2(0.0002332476)
      clg_cap_f_of_temp.setCoefficient4y(-0.003894048)
      clg_cap_f_of_temp.setCoefficient5yPOW2(-6.52536e-005)
      clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.0002680452)
      clg_cap_f_of_temp.setMinimumValueofx(5.0)
      clg_cap_f_of_temp.setMaximumValueofx(10.0)
      clg_cap_f_of_temp.setMinimumValueofy(24.0)
      clg_cap_f_of_temp.setMaximumValueofy(35.0)

      eir_f_of_avail_to_nom_cap = OpenStudio::Model::CurveBiquadratic.new(model)
      eir_f_of_avail_to_nom_cap.setCoefficient1Constant(0.70176857)
      eir_f_of_avail_to_nom_cap.setCoefficient2x(-0.00452016)
      eir_f_of_avail_to_nom_cap.setCoefficient3xPOW2(0.0005331096)
      eir_f_of_avail_to_nom_cap.setCoefficient4y(-0.005498208)
      eir_f_of_avail_to_nom_cap.setCoefficient5yPOW2(0.0005445792)
      eir_f_of_avail_to_nom_cap.setCoefficient6xTIMESY(-0.0007290324)
      eir_f_of_avail_to_nom_cap.setMinimumValueofx(5.0)
      eir_f_of_avail_to_nom_cap.setMaximumValueofx(10.0)
      eir_f_of_avail_to_nom_cap.setMinimumValueofy(24.0)
      eir_f_of_avail_to_nom_cap.setMaximumValueofy(35.0)

      eir_f_of_plr = OpenStudio::Model::CurveQuadratic.new(model)
      eir_f_of_plr.setCoefficient1Constant(0.06369119)
      eir_f_of_plr.setCoefficient2x(0.58488832)
      eir_f_of_plr.setCoefficient3xPOW2(0.35280274)
      eir_f_of_plr.setMinimumValueofx(0.0)
      eir_f_of_plr.setMaximumValueofx(1.0)

      chiller = OpenStudio::Model::ChillerElectricEIR.new(model,
                                                          clg_cap_f_of_temp,
                                                          eir_f_of_avail_to_nom_cap,
                                                          eir_f_of_plr)

      chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      # Add the components to the chilled water loop
      chw_supply_inlet_node = chw_loop.supplyInletNode
      chw_supply_outlet_node = chw_loop.supplyOutletNode
      chw_pump.addToNode(chw_supply_inlet_node)
      chw_loop.addSupplyBranchForComponent(chiller)
      chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
      chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

      # Add a setpoint manager to control the
      # chilled water to a constant temperature
      chw_t_c = OpenStudio.convert(44, 'F', 'C').get
      chw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      chw_t_sch.setName('CHW Temp')
      chw_t_sch.defaultDaySchedule.setName('HW Temp Default')
      chw_t_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), chw_t_c)
      chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_t_sch)
      chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

    end

    # Condenser System
    cw_loop = nil
    model.getLoops.sort.each do |loop|
      if loop.name.to_s == 'Condenser Water Loop'
        cw_loop = loop.to_PlantLoop.get
      end
    end

    if cw_loop.nil?
      cw_loop = OpenStudio::Model::PlantLoop.new(model)
      cw_loop.setName('Condenser Water Loop')
      cw_sizing_plant = cw_loop.sizingPlant
      cw_sizing_plant.setLoopType('Condenser')
      cw_sizing_plant.setDesignLoopExitTemperature(29.4) # TODO: units
      cw_sizing_plant.setLoopDesignTemperatureDifference(5.6)

      cw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

      clg_tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(model)

      clg_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      cw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      # Add the components to the condenser water loop
      cw_supply_inlet_node = cw_loop.supplyInletNode
      cw_supply_outlet_node = cw_loop.supplyOutletNode
      cw_pump.addToNode(cw_supply_inlet_node)
      cw_loop.addSupplyBranchForComponent(clg_tower)
      cw_loop.addSupplyBranchForComponent(clg_tower_bypass_pipe)
      cw_supply_outlet_pipe.addToNode(cw_supply_outlet_node)
      cw_loop.addDemandBranchForComponent(chiller)

      # Add a setpoint manager to control the
      # condenser water to follow the OA temp
      cw_t_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
      cw_t_stpt_manager.addToNode(cw_supply_outlet_node)

    end

    return chw_loop
  end

  def self.get_or_add_air_cooled_chiller_loop(model)
    # Chilled Water Plant
    chw_loop = nil
    model.getLoops.sort.each do |loop|
      if loop.name.to_s == 'Chilled Water Loop'
        chw_loop = loop.to_PlantLoop.get
      end
    end

    if chw_loop.nil?
      chw_loop = OpenStudio::Model::PlantLoop.new(model)
      chw_loop.setName('Chilled Water Loop')
      chw_sizing_plant = chw_loop.sizingPlant
      chw_sizing_plant.setLoopType('Cooling')
      chw_sizing_plant.setDesignLoopExitTemperature(7.22) # TODO: units
      chw_sizing_plant.setLoopDesignTemperatureDifference(6.67)

      chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp.setCoefficient1Constant(1.0215158)
      clg_cap_f_of_temp.setCoefficient2x(0.037035864)
      clg_cap_f_of_temp.setCoefficient3xPOW2(0.0002332476)
      clg_cap_f_of_temp.setCoefficient4y(-0.003894048)
      clg_cap_f_of_temp.setCoefficient5yPOW2(-6.52536e-005)
      clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.0002680452)
      clg_cap_f_of_temp.setMinimumValueofx(5.0)
      clg_cap_f_of_temp.setMaximumValueofx(10.0)
      clg_cap_f_of_temp.setMinimumValueofy(24.0)
      clg_cap_f_of_temp.setMaximumValueofy(35.0)

      eir_f_of_avail_to_nom_cap = OpenStudio::Model::CurveBiquadratic.new(model)
      eir_f_of_avail_to_nom_cap.setCoefficient1Constant(0.70176857)
      eir_f_of_avail_to_nom_cap.setCoefficient2x(-0.00452016)
      eir_f_of_avail_to_nom_cap.setCoefficient3xPOW2(0.0005331096)
      eir_f_of_avail_to_nom_cap.setCoefficient4y(-0.005498208)
      eir_f_of_avail_to_nom_cap.setCoefficient5yPOW2(0.0005445792)
      eir_f_of_avail_to_nom_cap.setCoefficient6xTIMESY(-0.0007290324)
      eir_f_of_avail_to_nom_cap.setMinimumValueofx(5.0)
      eir_f_of_avail_to_nom_cap.setMaximumValueofx(10.0)
      eir_f_of_avail_to_nom_cap.setMinimumValueofy(24.0)
      eir_f_of_avail_to_nom_cap.setMaximumValueofy(35.0)

      eir_f_of_plr = OpenStudio::Model::CurveQuadratic.new(model)
      eir_f_of_plr.setCoefficient1Constant(0.06369119)
      eir_f_of_plr.setCoefficient2x(0.58488832)
      eir_f_of_plr.setCoefficient3xPOW2(0.35280274)
      eir_f_of_plr.setMinimumValueofx(0.0)
      eir_f_of_plr.setMaximumValueofx(1.0)

      chiller = OpenStudio::Model::ChillerElectricEIR.new(model,
                                                          clg_cap_f_of_temp,
                                                          eir_f_of_avail_to_nom_cap,
                                                          eir_f_of_plr)

      chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

      # Add the components to the chilled water loop
      chw_supply_inlet_node = chw_loop.supplyInletNode
      chw_supply_outlet_node = chw_loop.supplyOutletNode
      chw_pump.addToNode(chw_supply_inlet_node)
      chw_loop.addSupplyBranchForComponent(chiller)
      chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
      chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

      # Add a setpoint manager to control the
      # chilled water to a constant temperature
      chw_t_c = OpenStudio.convert(44, 'F', 'C').get
      chw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      chw_t_sch.setName('CHW Temp')
      chw_t_sch.defaultDaySchedule.setName('HW Temp Default')
      chw_t_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), chw_t_c)
      chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_t_sch)
      chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

    end

    return chw_loop
  end

  def self._add_coil_cooling_dx_two_speed(model)
    clg_coil = nil

    always_on = model.alwaysOnDiscreteSchedule

    clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
    clg_cap_f_of_temp.setCoefficient2x(0.04426)
    clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
    clg_cap_f_of_temp.setCoefficient4y(0.00333)
    clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
    clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
    clg_cap_f_of_temp.setMinimumValueofx(17.0)
    clg_cap_f_of_temp.setMaximumValueofx(22.0)
    clg_cap_f_of_temp.setMinimumValueofy(13.0)
    clg_cap_f_of_temp.setMaximumValueofy(46.0)

    clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
    clg_cap_f_of_flow.setCoefficient2x(0.34053)
    clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
    clg_cap_f_of_flow.setMinimumValueofx(0.75918)
    clg_cap_f_of_flow.setMaximumValueofx(1.13877)

    clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
    clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
    clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
    clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
    clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
    clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

    clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
    clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
    clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
    clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
    clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

    clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
    clg_part_load_ratio.setCoefficient1Constant(0.77100)
    clg_part_load_ratio.setCoefficient2x(0.22900)
    clg_part_load_ratio.setCoefficient3xPOW2(0.0)
    clg_part_load_ratio.setMinimumValueofx(0.0)
    clg_part_load_ratio.setMaximumValueofx(1.0)

    clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
    clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
    clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
    clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
    clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
    clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
    clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
    clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
    clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
    clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

    clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
    clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
    clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
    clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
    clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
    clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
    clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
    clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
    clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
    clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

    clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                                                            always_on,
                                                            clg_cap_f_of_temp,
                                                            clg_cap_f_of_flow,
                                                            clg_energy_input_ratio_f_of_temp,
                                                            clg_energy_input_ratio_f_of_flow,
                                                            clg_part_load_ratio,
                                                            clg_cap_f_of_temp_low_spd,
                                                            clg_energy_input_ratio_f_of_temp_low_spd)

    clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
    clg_coil.setBasinHeaterCapacity(10)
    clg_coil.setBasinHeaterSetpointTemperature(2.0)

    return clg_coil
  end

  def self._add_coil_cooling_dx_single_speed_sys_type_1(model)
    clg_coil = nil

    always_on = model.alwaysOnDiscreteSchedule

    clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_cap_f_of_temp.setCoefficient1Constant(0.942587793)
    clg_cap_f_of_temp.setCoefficient2x(0.009543347)
    clg_cap_f_of_temp.setCoefficient3xPOW2(0.000683770)
    clg_cap_f_of_temp.setCoefficient4y(-0.011042676)
    clg_cap_f_of_temp.setCoefficient5yPOW2(0.000005249)
    clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.000009720)
    clg_cap_f_of_temp.setMinimumValueofx(17.0)
    clg_cap_f_of_temp.setMaximumValueofx(22.0)
    clg_cap_f_of_temp.setMinimumValueofy(13.0)
    clg_cap_f_of_temp.setMaximumValueofy(46.0)

    clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_cap_f_of_flow.setCoefficient1Constant(0.8)
    clg_cap_f_of_flow.setCoefficient2x(0.2)
    clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
    clg_cap_f_of_flow.setMinimumValueofx(0.5)
    clg_cap_f_of_flow.setMaximumValueofx(1.5)

    energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    energy_input_ratio_f_of_temp.setCoefficient1Constant(0.342414409)
    energy_input_ratio_f_of_temp.setCoefficient2x(0.034885008)
    energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000623700)
    energy_input_ratio_f_of_temp.setCoefficient4y(0.004977216)
    energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000437951)
    energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000728028)
    energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
    energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
    energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
    energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

    energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
    energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
    energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
    energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
    energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

    part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
    part_load_fraction.setCoefficient1Constant(0.85)
    part_load_fraction.setCoefficient2x(0.15)
    part_load_fraction.setCoefficient3xPOW2(0.0)
    part_load_fraction.setMinimumValueofx(0.0)
    part_load_fraction.setMaximumValueofx(1.0)

    clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                               always_on,
                                                               clg_cap_f_of_temp,
                                                               clg_cap_f_of_flow,
                                                               energy_input_ratio_f_of_temp,
                                                               energy_input_ratio_f_of_flow,
                                                               part_load_fraction)

    return clg_coil
  end

  def self._add_coil_cooling_dx_single_speed_sys_type_2(model)
    clg_coil = nil

    always_on = model.alwaysOnDiscreteSchedule

    clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_cap_f_of_temp.setCoefficient1Constant(0.942587793)
    clg_cap_f_of_temp.setCoefficient2x(0.009543347)
    clg_cap_f_of_temp.setCoefficient3xPOW2(0.0018423)
    clg_cap_f_of_temp.setCoefficient4y(-0.011042676)
    clg_cap_f_of_temp.setCoefficient5yPOW2(0.000005249)
    clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.000009720)
    clg_cap_f_of_temp.setMinimumValueofx(17.0)
    clg_cap_f_of_temp.setMaximumValueofx(22.0)
    clg_cap_f_of_temp.setMinimumValueofy(13.0)
    clg_cap_f_of_temp.setMaximumValueofy(46.0)

    clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_cap_f_of_flow.setCoefficient1Constant(0.718954)
    clg_cap_f_of_flow.setCoefficient2x(0.435436)
    clg_cap_f_of_flow.setCoefficient3xPOW2(-0.154193)
    clg_cap_f_of_flow.setMinimumValueofx(0.75)
    clg_cap_f_of_flow.setMaximumValueofx(1.25)

    clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.342414409)
    clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.034885008)
    clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000623700)
    clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.004977216)
    clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000437951)
    clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000728028)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

    clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
    clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
    clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
    clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
    clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

    clg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
    clg_part_load_fraction.setCoefficient1Constant(0.75)
    clg_part_load_fraction.setCoefficient2x(0.25)
    clg_part_load_fraction.setCoefficient3xPOW2(0.0)
    clg_part_load_fraction.setMinimumValueofx(0.0)
    clg_part_load_fraction.setMaximumValueofx(1.0)

    clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                               always_on,
                                                               clg_cap_f_of_temp,
                                                               clg_cap_f_of_flow,
                                                               clg_energy_input_ratio_f_of_temp,
                                                               clg_energy_input_ratio_f_of_flow,
                                                               clg_part_load_fraction)

    return clg_coil
  end

  def self._add_coil_cooling_dx_single_speed_sys_type_3(model)
    clg_coil = nil

    always_on = model.alwaysOnDiscreteSchedule

    clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
    clg_cap_f_of_temp.setCoefficient2x(0.04426)
    clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
    clg_cap_f_of_temp.setCoefficient4y(0.00333)
    clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
    clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
    clg_cap_f_of_temp.setMinimumValueofx(17.0)
    clg_cap_f_of_temp.setMaximumValueofx(22.0)
    clg_cap_f_of_temp.setMinimumValueofy(13.0)
    clg_cap_f_of_temp.setMaximumValueofy(46.0)

    clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
    clg_cap_f_of_flow.setCoefficient2x(0.34053)
    clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
    clg_cap_f_of_flow.setMinimumValueofx(0.75918)
    clg_cap_f_of_flow.setMaximumValueofx(1.13877)

    clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
    clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
    clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
    clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
    clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
    clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

    clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
    clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
    clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
    clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
    clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

    clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
    clg_part_load_ratio.setCoefficient1Constant(0.77100)
    clg_part_load_ratio.setCoefficient2x(0.22900)
    clg_part_load_ratio.setCoefficient3xPOW2(0.0)
    clg_part_load_ratio.setMinimumValueofx(0.0)
    clg_part_load_ratio.setMaximumValueofx(1.0)

    clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                               always_on,
                                                               clg_cap_f_of_temp,
                                                               clg_cap_f_of_flow,
                                                               clg_energy_input_ratio_f_of_temp,
                                                               clg_energy_input_ratio_f_of_flow,
                                                               clg_part_load_ratio)

    return clg_coil
  end

  def self._add_coil_cooling_dx_single_speed_sys_type_4(model)
    clg_coil = nil

    always_on = model.alwaysOnDiscreteSchedule

    clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_cap_f_of_temp.setCoefficient1Constant(0.766956)
    clg_cap_f_of_temp.setCoefficient2x(0.0107756)
    clg_cap_f_of_temp.setCoefficient3xPOW2(-0.0000414703)
    clg_cap_f_of_temp.setCoefficient4y(0.00134961)
    clg_cap_f_of_temp.setCoefficient5yPOW2(-0.000261144)
    clg_cap_f_of_temp.setCoefficient6xTIMESY(0.000457488)
    clg_cap_f_of_temp.setMinimumValueofx(17.0)
    clg_cap_f_of_temp.setMaximumValueofx(22.0)
    clg_cap_f_of_temp.setMinimumValueofy(13.0)
    clg_cap_f_of_temp.setMaximumValueofy(46.0)

    clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_cap_f_of_flow.setCoefficient1Constant(0.8)
    clg_cap_f_of_flow.setCoefficient2x(0.2)
    clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
    clg_cap_f_of_flow.setMinimumValueofx(0.5)
    clg_cap_f_of_flow.setMaximumValueofx(1.5)

    clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.297145)
    clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.0430933)
    clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000748766)
    clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.00597727)
    clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000482112)
    clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000956448)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
    clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
    clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

    clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
    clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
    clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
    clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
    clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

    clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
    clg_part_load_ratio.setCoefficient1Constant(0.75)
    clg_part_load_ratio.setCoefficient2x(0.25)
    clg_part_load_ratio.setCoefficient3xPOW2(0.0)
    clg_part_load_ratio.setMinimumValueofx(0.0)
    clg_part_load_ratio.setMaximumValueofx(1.0)

    clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                               always_on,
                                                               clg_cap_f_of_temp,
                                                               clg_cap_f_of_flow,
                                                               clg_energy_input_ratio_f_of_temp,
                                                               clg_energy_input_ratio_f_of_flow,
                                                               clg_part_load_ratio)
    return clg_coil
  end

  def self._add_coil_heating_dx_single_speed(model)
    htg_coil = nil

    always_on = model.alwaysOnDiscreteSchedule

    htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
    htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
    htg_cap_f_of_temp.setCoefficient2x(0.027626)
    htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
    htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
    htg_cap_f_of_temp.setMinimumValueofx(-20.0)
    htg_cap_f_of_temp.setMaximumValueofx(20.0)

    htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
    htg_cap_f_of_flow.setCoefficient1Constant(0.84)
    htg_cap_f_of_flow.setCoefficient2x(0.16)
    htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
    htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
    htg_cap_f_of_flow.setMinimumValueofx(0.5)
    htg_cap_f_of_flow.setMaximumValueofx(1.5)

    htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
    htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
    htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
    htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
    htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
    htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
    htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

    htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
    htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
    htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
    htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
    htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
    htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

    htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
    htg_part_load_fraction.setCoefficient1Constant(0.75)
    htg_part_load_fraction.setCoefficient2x(0.25)
    htg_part_load_fraction.setCoefficient3xPOW2(0.0)
    htg_part_load_fraction.setMinimumValueofx(0.0)
    htg_part_load_fraction.setMaximumValueofx(1.0)

    htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                                                               always_on,
                                                               htg_cap_f_of_temp,
                                                               htg_cap_f_of_flow,
                                                               htg_energy_input_ratio_f_of_temp,
                                                               htg_energy_input_ratio_f_of_flow,
                                                               htg_part_load_fraction)

    return htg_coil
  end
end
