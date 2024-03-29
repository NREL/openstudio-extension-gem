# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module OsLib_QAQC
  # include any general notes about QAQC method here
  # 'standard performance curves' based on what is in OpenStudio standards for prototype building
  # initially the tollerance will be hard coded vs. passed in as a method argument

  # checks the number of unmet hours in the model
  def check_mech_sys_part_load_eff(category, target_standard, min_pass, max_pass, name_only = false)
    if target_standard.include?('90.1')
      display_standard = "ASHRAE #{target_standard}"
    else
      display_standard = target_standard
    end

    component_type_array = ['ChillerElectricEIR', 'CoilCoolingDXSingleSpeed', 'CoilCoolingDXTwoSpeed', 'CoilHeatingDXSingleSpeed']

    # summary of the check
    check_elems = OpenStudio::AttributeVector.new
    check_elems << OpenStudio::Attribute.new('name', 'Mechanical System Part Load Efficiency')
    check_elems << OpenStudio::Attribute.new('category', category)
    check_elems << OpenStudio::Attribute.new('description', "Check 40% and 80% part load efficency against #{display_standard} for the following compenent types: #{component_type_array.join(', ')}. Checking EIR Function of Part Load Ratio curve for chiller and EIR Function of Flow Fraction for DX coils.")
    # TODO: - add in check for VAV fan

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      results = []
      check_elems.each do |elem|
        results << elem.valueAsString
      end
      return results
    end

    # Versions of OpenStudio greater than 2.4.0 use a modified version of
    # openstudio-standards with different method calls.  These methods
    # require a "Standard" object instead of the standard being passed into method calls.
    # This Standard object is used throughout the QAQC check.
    if OpenStudio::VersionString.new(OpenStudio.openStudioVersion) < OpenStudio::VersionString.new('2.4.3')
      use_old_gem_code = true
    else
      use_old_gem_code = false
      std = Standard.build(target_standard)
    end

    begin
      # TODO: - in future would be nice to dynamically genrate list of possible options from standards json
      chiller_air_cooled_condenser_types = ['WithCondenser', 'WithoutCondenser']
      chiller_water_cooled_compressor_types = ['Reciprocating', 'Scroll', 'Rotary Screw', 'Centrifugal']
      absorption_types = ['Single Effect', 'Double Effect Indirect Fired', 'Double Effect Direct Fired']

      # check getChillerElectricEIRs objects (will also have curve check in different script)
      @model.getChillerElectricEIRs.each do |component|
        # get curve and evaluate
        electric_input_to_cooling_output_ratio_function_of_PLR = component.electricInputToCoolingOutputRatioFunctionOfPLR
        curve_40_pct = electric_input_to_cooling_output_ratio_function_of_PLR.evaluate(0.4)
        curve_80_pct = electric_input_to_cooling_output_ratio_function_of_PLR.evaluate(0.8)

        # find ac properties
        if use_old_gem_code
          search_criteria = component.find_search_criteria(target_standard)
        else
          search_criteria = std.chiller_electric_eir_find_search_criteria(component)
        end

        # extend search_criteria for absorption_type
        absorption_types.each do |absorption_type|
          if component.name.to_s.include?(absorption_type)
            search_criteria['absorption_type'] = absorption_type
            next
          end
        end
        # extend search_criteria for condenser type or compressor type
        if search_criteria['cooling_type'] == 'AirCooled'
          chiller_air_cooled_condenser_types.each do |condenser_type|
            if component.name.to_s.include?(condenser_type)
              search_criteria['condenser_type'] = condenser_type
              next
            end
          end
          # if no match and also no absorption_type then issue warning
          if !search_criteria.key?('condenser_type') || search_criteria['condenser_type'].nil?
            if !search_criteria.key?('absorption_type') || search_criteria['absorption_type'].nil?
              check_elems <<  OpenStudio::Attribute.new('flag', "Can't find unique search criteria for #{component.name}. #{search_criteria}")
              next # don't go past here
            end
          end
        elsif search_criteria['cooling_type'] == 'WaterCooled'
          chiller_air_cooled_condenser_types.each do |compressor_type|
            if component.name.to_s.include?(compressor_type)
              search_criteria['compressor_type'] = compressor_type
              next
            end
          end
          # if no match and also no absorption_type then issue warning
          if !search_criteria.key?('compressor_type') || search_criteria['compressor_type'].nil?
            if !search_criteria.key?('absorption_type') || search_criteria['absorption_type'].nil?
              check_elems <<  OpenStudio::Attribute.new('flag', "Can't find unique search criteria for #{component.name}. #{search_criteria}")
              next # don't go past here
            end
          end
        end

        # lookup chiller
        if use_old_gem_code
          capacity_w = component.find_capacity
        else
          capacity_w = std.chiller_electric_eir_find_capacity(component)
        end
        capacity_tons = OpenStudio.convert(capacity_w, 'W', 'ton').get

        if use_old_gem_code
          chlr_props = component.model.find_object($os_standards['chillers'], search_criteria, capacity_tons, Date.today)
          chlr_props
          chlr_props = std.model_find_object(std.standards_data['chillers'], search_criteria, capacity_tons, Date.today)
        end
        if chlr_props.nil?
          check_elems <<  OpenStudio::Attribute.new('flag', "Didn't find chiller for #{component.name}. #{search_criteria}")
          next # don't go past here in loop if can't find curve
        end

        # temp model to hold temp curve
        model_temp = OpenStudio::Model::Model.new

        # create temp curve
        target_curve_name = chlr_props['eirfplr']
        if target_curve_name.nil?
          check_elems <<  OpenStudio::Attribute.new('flag', "Can't find target eirfplr curve for #{component.name}")
          next # don't go past here in loop if can't find curve
        end
        if use_old_gem_code
          temp_curve = model_temp.add_curve(target_curve_name)
        else
          temp_curve = std.model_add_curve(model_temp, target_curve_name)
        end

        target_curve_40_pct = temp_curve.evaluate(0.4)
        target_curve_80_pct = temp_curve.evaluate(0.8)

        # check curve at two points
        if curve_40_pct < target_curve_40_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        elsif curve_40_pct > target_curve_40_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        end
        if curve_80_pct < target_curve_80_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        elsif curve_80_pct > target_curve_80_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        end
      end

      # check getCoilCoolingDXSingleSpeeds objects (will also have curve check in different script)
      @model.getCoilCoolingDXSingleSpeeds.each do |component|
        # get curve and evaluate
        eir_function_of_flow_fraction_curve = component.energyInputRatioFunctionOfFlowFractionCurve
        curve_40_pct = eir_function_of_flow_fraction_curve.evaluate(0.4)
        curve_80_pct = eir_function_of_flow_fraction_curve.evaluate(0.8)

        # find ac properties
        if use_old_gem_code
          search_criteria = component.find_search_criteria(target_standard)
        else
          search_criteria = std.coil_dx_find_search_criteria(component)
        end

        if use_old_gem_code
          capacity_w = component.find_capacity
        else
          capacity_w = std.coil_cooling_dx_single_speed_find_capacity(component)
        end
        capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

        if use_old_gem_code
          if component.heat_pump?
            ac_props = component.model.find_object($os_standards['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
          else
            ac_props = component.model.find_object($os_standards['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
          end
        else
          if std.coil_dx_heat_pump?(component)
            ac_props = std.model_find_object(std.standards_data['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
          else
            ac_props = std.model_find_object(std.standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
          end
        end

        # temp model to hold temp curve
        model_temp = OpenStudio::Model::Model.new

        # create temp curve
        target_curve_name = ac_props['cool_eir_fflow']
        if target_curve_name.nil?
          check_elems <<  OpenStudio::Attribute.new('flag', "Can't find target cool_eir_fflow curve for #{component.name}")
          next # don't go past here in loop if can't find curve
        end
        if use_old_gem_code
          temp_curve = model_temp.add_curve(target_curve_name)
        else
          temp_curve = std.model_add_curve(model_temp, target_curve_name)
        end
        target_curve_40_pct = temp_curve.evaluate(0.4)
        target_curve_80_pct = temp_curve.evaluate(0.8)

        # check curve at two points
        if curve_40_pct < target_curve_40_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        elsif curve_40_pct > target_curve_40_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        end
        if curve_80_pct < target_curve_80_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        elsif curve_80_pct > target_curve_80_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        end
      end

      # check CoilCoolingDXTwoSpeed objects (will also have curve check in different script)
      @model.getCoilCoolingDXTwoSpeeds.each do |component|
        # get curve and evaluate
        eir_function_of_flow_fraction_curve = component.energyInputRatioFunctionOfFlowFractionCurve
        curve_40_pct = eir_function_of_flow_fraction_curve.evaluate(0.4)
        curve_80_pct = eir_function_of_flow_fraction_curve.evaluate(0.8)

        # find ac properties
        if use_old_gem_code
          search_criteria = component.find_search_criteria(target_standard)
        else
          search_criteria = std.coil_dx_find_search_criteria(component)
        end

        if use_old_gem_code
          capacity_w = component.find_capacity
        else
          capacity_w = std.coil_cooling_dx_two_speed_find_capacity(component)
        end
        capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

        if use_old_gem_code
          ac_props = component.model.find_object($os_standards['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
        else
          ac_props = std.model_find_object(std.standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
        end

        # temp model to hold temp curve
        model_temp = OpenStudio::Model::Model.new

        # create temp curve
        target_curve_name = ac_props['cool_eir_fflow']
        if target_curve_name.nil?
          check_elems <<  OpenStudio::Attribute.new('flag', "Can't find target cool_eir_flow curve for #{component.name}")
          next # don't go past here in loop if can't find curve
        end
        if use_old_gem_code
          temp_curve = model_temp.add_curve(target_curve_name)
        else
          temp_curve = std.model_add_curve(model_temp, target_curve_name)
        end
        target_curve_40_pct = temp_curve.evaluate(0.4)
        target_curve_80_pct = temp_curve.evaluate(0.8)

        # check curve at two points
        if curve_40_pct < target_curve_40_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        elsif curve_40_pct > target_curve_40_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        end
        if curve_80_pct < target_curve_80_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        elsif curve_80_pct > target_curve_80_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        end
      end

      # check CoilCoolingDXTwoSpeed objects (will also have curve check in different script)
      @model.getCoilHeatingDXSingleSpeeds.each do |component|
        # get curve and evaluate
        eir_function_of_flow_fraction_curve = component.energyInputRatioFunctionofFlowFractionCurve # why lowercase of here but not in CoilCoolingDX objects
        curve_40_pct = eir_function_of_flow_fraction_curve.evaluate(0.4)
        curve_80_pct = eir_function_of_flow_fraction_curve.evaluate(0.8)

        # find ac properties
        if use_old_gem_code
          search_criteria = component.find_search_criteria(target_standard)
        else
          search_criteria = std.coil_dx_find_search_criteria(component)
        end

        if use_old_gem_code
          capacity_w = component.find_capacity
        else
          capacity_w = std.coil_heating_dx_single_speed_find_capacity(component)
        end
        capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

        if use_old_gem_code
          ac_props = component.model.find_object($os_standards['heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)
        else
          ac_props = std.model_find_object(std.standards_data['heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)
        end
        if ac_props.nil?
          target_curve_name = nil
        else
          target_curve_name = ac_props['heat_eir_fflow']
        end

        # temp model to hold temp curve
        model_temp = OpenStudio::Model::Model.new

        # create temp curve
        if target_curve_name.nil?
          check_elems <<  OpenStudio::Attribute.new('flag', "Can't find target curve for #{component.name}")
          next # don't go past here in loop if can't find curve
        end
        if use_old_gem_code
          temp_curve = model_temp.add_curve(target_curve_name)
        else
          temp_curve = std.model_add_curve(model_temp, target_curve_name)
        end

        # Ensure that the curve was found in standards before attempting to evaluate
        if temp_curve.nil?
          check_elems << OpenStudio::Attribute.new('flag', "Can't find coefficients of curve called #{target_curve_name} for #{component.name}, cannot check part-load performance.")
          next
        end

        target_curve_40_pct = temp_curve.evaluate(0.4)
        target_curve_80_pct = temp_curve.evaluate(0.8)

        # check curve at two points
        if curve_40_pct < target_curve_40_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        elsif curve_40_pct > target_curve_40_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        end
        if curve_80_pct < target_curve_80_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        elsif curve_80_pct > target_curve_80_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        end
      end

      # check
      @model.getFanVariableVolumes.each do |component|
        # skip if not on multi-zone system.
        if component.airLoopHVAC.is_initialized
          airloop = component.airLoopHVAC.get

          next unless airloop.thermalZones.size > 1.0
        end

        # skip of brake horsepower is 0
        if use_old_gem_code
          next if component.brake_horsepower == 0.0
        else
          next if std.fan_brake_horsepower(component) == 0.0
        end

        # temp model for use by temp model and target curve
        model_temp = OpenStudio::Model::Model.new

        # get coeficents for fan
        model_fan_coefs = []
        model_fan_coefs << component.fanPowerCoefficient1.get
        model_fan_coefs << component.fanPowerCoefficient2.get
        model_fan_coefs << component.fanPowerCoefficient3.get
        model_fan_coefs << component.fanPowerCoefficient4.get
        model_fan_coefs << component.fanPowerCoefficient5.get

        # make model curve
        model_curve = OpenStudio::Model::CurveQuartic.new(model_temp)
        model_curve.setCoefficient1Constant(model_fan_coefs[0])
        model_curve.setCoefficient2x(model_fan_coefs[1])
        model_curve.setCoefficient3xPOW2(model_fan_coefs[2])
        model_curve.setCoefficient4xPOW3(model_fan_coefs[3])
        model_curve.setCoefficient5xPOW4(model_fan_coefs[4])
        curve_40_pct = model_curve.evaluate(0.4)
        curve_80_pct = model_curve.evaluate(0.8)

        # get target coefs
        target_fan = OpenStudio::Model::FanVariableVolume.new(model_temp)
        if use_old_gem_code
          target_fan.set_control_type('Multi Zone VAV with Static Pressure Reset')
        else
          std.fan_variable_volume_set_control_type(target_fan, 'Multi Zone VAV with VSD and Static Pressure Reset')
        end

        # get coeficents for fan
        target_fan_coefs = []
        target_fan_coefs << target_fan.fanPowerCoefficient1.get
        target_fan_coefs << target_fan.fanPowerCoefficient2.get
        target_fan_coefs << target_fan.fanPowerCoefficient3.get
        target_fan_coefs << target_fan.fanPowerCoefficient4.get
        target_fan_coefs << target_fan.fanPowerCoefficient5.get

        # make model curve
        target_curve = OpenStudio::Model::CurveQuartic.new(model_temp)
        target_curve.setCoefficient1Constant(target_fan_coefs[0])
        target_curve.setCoefficient2x(target_fan_coefs[1])
        target_curve.setCoefficient3xPOW2(target_fan_coefs[2])
        target_curve.setCoefficient4xPOW3(target_fan_coefs[3])
        target_curve.setCoefficient5xPOW4(target_fan_coefs[4])
        target_curve_40_pct = target_curve.evaluate(0.4)
        target_curve_80_pct = target_curve.evaluate(0.8)

        # check curve at two points
        if curve_40_pct < target_curve_40_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        elsif curve_40_pct > target_curve_40_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 40% of #{curve_40_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_40_pct.round(2)} for #{display_standard}.")
        end
        if curve_80_pct < target_curve_80_pct * (1.0 - min_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{min_pass * 100} % below the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        elsif curve_80_pct > target_curve_80_pct * (1.0 + max_pass)
          check_elems <<  OpenStudio::Attribute.new('flag', "The curve value at 80% of #{curve_80_pct.round(2)} for #{component.name} is more than #{max_pass * 100} % above the typical value of #{target_curve_80_pct.round(2)} for #{display_standard}.")
        end
      end
    rescue StandardError => e
      # brief description of ruby error
      check_elems << OpenStudio::Attribute.new('flag', "Error prevented QAQC check from running (#{e}).")

      # backtrace of ruby error for diagnostic use
      if @error_backtrace then check_elems << OpenStudio::Attribute.new('flag', e.backtrace.join("\n").to_s) end
    end

    # add check_elms to new attribute
    check_elem = OpenStudio::Attribute.new('check', check_elems)

    return check_elem
    # note: registerWarning and registerValue will be added for checks downstream using os_lib_reporting_qaqc.rb
  end
end
