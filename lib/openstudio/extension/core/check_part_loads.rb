# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module OsLib_QAQC
  # Bin the hourly part load ratios into 10% bins
  def bin_part_loads_by_ten_pcts(hrly_plrs)
    bins = Array.new(10, 0)
    op_hrs = 0.0
    hrly_plrs.each do |plr|
      op_hrs += 1.0 if plr > 0
      if plr <= 0.1 # add below-zero % PLRs to final bin
        bins[0] += 1
      elsif plr > 0.1 && plr <= 0.2
        bins[1] += 1
      elsif plr > 0.2 && plr <= 0.3
        bins[2] += 1
      elsif plr > 0.3 && plr <= 0.4
        bins[3] += 1
      elsif plr > 0.4 && plr <= 0.5
        bins[4] += 1
      elsif plr > 0.5 && plr <= 0.6
        bins[5] += 1
      elsif plr > 0.6 && plr <= 0.7
        bins[6] += 1
      elsif plr > 0.7 && plr <= 0.8
        bins[7] += 1
      elsif plr > 0.8 && plr <= 0.9
        bins[8] += 1
      elsif plr > 0.9 # add over-100% PLRs to final bin
        bins[9] += 1
      end
    end

    # Convert bins from hour counts to % of operating hours.
    bins.each_with_index do |bin, i|
      bins[i] = bins[i] / op_hrs
    end

    return bins
  end

  # Check primary heating and cooling equipment part load ratios
  # to find equipment that is significantly oversized or undersized.
  def check_part_loads(category, target_standard, max_pct_delta = 0.1, name_only = false)
    # summary of the check
    check_elems = OpenStudio::AttributeVector.new
    check_elems << OpenStudio::Attribute.new('name', 'Part Load')
    check_elems << OpenStudio::Attribute.new('category', category)
    check_elems << OpenStudio::Attribute.new('description', 'Check that equipment operates at reasonable part load ranges.')

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      results = []
      check_elems.each do |elem|
        results << elem.valueAsString
      end
      return results
    end

    std = Standard.build(target_standard)

    begin
      # Establish limits for % of operating hrs expected above 90% part load
      expected_pct_hrs_above_90 = 0.1

      # get the weather file run period (as opposed to design day run period)
      ann_env_pd = nil
      @sql.availableEnvPeriods.each do |env_pd|
        env_type = @sql.environmentType(env_pd)
        if env_type.is_initialized
          if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
            ann_env_pd = env_pd
            break
          end
        end
      end

      # only try to get the annual timeseries if an annual simulation was run
      if ann_env_pd.nil?
        check_elems << OpenStudio::Attribute.new('flag', 'Cannot find the annual simulation run period, cannot check equipment part load ratios.')
        return check_elem
      end

      # Boilers
      @model.getBoilerHotWaters.each do |equip|
        # Get the timeseries part load ratio data
        key_value =  equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Boiler Part Load Ratio'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i]
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # Chillers
      @model.getChillerElectricEIRs.each do |equip|
        # Get the timeseries part load ratio data
        key_value =  equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Chiller Part Load Ratio'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i]
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # Cooling Towers (Single Speed)
      @model.getCoolingTowerSingleSpeeds.each do |equip|
        # Get the design fan power
        if equip.fanPoweratDesignAirFlowRate.is_initialized
          dsn_pwr = equip.fanPoweratDesignAirFlowRate.get
        elsif equip.autosizedFanPoweratDesignAirFlowRate.is_initialized
          dsn_pwr = equip.autosizedFanPoweratDesignAirFlowRate.get
        else
          check_elems << OpenStudio::Attribute.new('flag', "Could not determine peak power for #{equip.name}, cannot check part load ratios.")
          next
        end

        # Get the timeseries fan power
        key_value = equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Cooling Tower Fan Electric Power'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i] / dsn_pwr.to_f
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # Cooling Towers (Two Speed)
      @model.getCoolingTowerTwoSpeeds.each do |equip|
        # Get the design fan power
        if equip.highFanSpeedFanPower.is_initialized
          dsn_pwr = equip.highFanSpeedFanPower.get
        elsif equip.autosizedHighFanSpeedFanPower.is_initialized
          dsn_pwr = equip.autosizedHighFanSpeedFanPower.get
        else
          check_elems << OpenStudio::Attribute.new('flag', "Could not determine peak power for #{equip.name}, cannot check part load ratios.")
          next
        end

        # Get the timeseries fan power
        key_value = equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Cooling Tower Fan Electric Power'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i] / dsn_pwr.to_f
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # Cooling Towers (Variable Speed)
      @model.getCoolingTowerVariableSpeeds.each do |equip|
        # Get the design fan power
        if equip.designFanPower.is_initialized
          dsn_pwr = equip.designFanPower.get
        elsif equip.autosizedDesignFanPower.is_initialized
          dsn_pwr = equip.autosizedDesignFanPower.get
        else
          check_elems << OpenStudio::Attribute.new('flag', "Could not determine peak power for #{equip.name}, cannot check part load ratios.")
          next
        end

        # Get the timeseries fan power
        key_value = equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Cooling Tower Fan Electric Power'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i] / dsn_pwr.to_f
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # DX Cooling Coils (Single Speed)
      @model.getCoilCoolingDXSingleSpeeds.each do |equip|
        # Get the design coil capacity
        if equip.grossRatedTotalCoolingCapacity.is_initialized
          dsn_pwr = equip.grossRatedTotalCoolingCapacity.get
        elsif equip.autosizedGrossRatedTotalCoolingCapacity.is_initialized
          dsn_pwr = equip.autosizedGrossRatedTotalCoolingCapacity.get
        else
          check_elems << OpenStudio::Attribute.new('flag', "Could not determine capacity for #{equip.name}, cannot check part load ratios.")
          next
        end

        # Get the timeseries coil capacity
        key_value = equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Cooling Coil Total Cooling Rate'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i] / dsn_pwr.to_f
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # DX Cooling Coils (Two Speed)
      @model.getCoilCoolingDXTwoSpeeds.each do |equip|
        # Get the design coil capacity
        if equip.ratedHighSpeedTotalCoolingCapacity.is_initialized
          dsn_pwr = equip.ratedHighSpeedTotalCoolingCapacity.get
        elsif equip.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
          dsn_pwr = equip.autosizedRatedHighSpeedTotalCoolingCapacity.get
        else
          check_elems << OpenStudio::Attribute.new('flag', "Could not determine capacity for #{equip.name}, cannot check part load ratios.")
          next
        end

        # Get the timeseries coil capacity
        key_value = equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Cooling Coil Total Cooling Rate'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i] / dsn_pwr.to_f
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # DX Cooling Coils (Variable Speed)
      @model.getCoilCoolingDXVariableSpeeds.each do |equip|
        # Get the design coil capacity
        if equip.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
          dsn_pwr = equip.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
        elsif equip.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
          dsn_pwr = equip.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
        else
          check_elems << OpenStudio::Attribute.new('flag', "Could not determine capacity for #{equip.name}, cannot check part load ratios.")
          next
        end

        # Get the timeseries coil capacity
        key_value = equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Cooling Coil Total Cooling Rate'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i] / dsn_pwr.to_f
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
        end
      end

      # Gas Heating Coils
      @model.getCoilHeatingGass.each do |equip|
        # Get the design coil capacity
        if equip.nominalCapacity.is_initialized
          dsn_pwr = equip.nominalCapacity.get
        elsif equip.autosizedNominalCapacity.is_initialized
          dsn_pwr = equip.autosizedNominalCapacity.get
        else
          check_elems << OpenStudio::Attribute.new('flag', "Could not determine capacity for #{equip.name}, cannot check part load ratios.")
          next
        end

        # Get the timeseries coil capacity
        key_value = equip.name.get.to_s.upcase # must be in all caps.
        time_step = 'Hourly'
        variable_name = 'Heating Coil Air Heating Rate'
        ts = @sql.timeSeries(ann_env_pd, time_step, variable_name, key_value)
        if ts.empty?
          check_elems << OpenStudio::Attribute.new('flag', "#{variable_name} Timeseries not found for #{key_value}.")
          next
        end

        # Convert to array
        ts = ts.get.values
        plrs = []
        for i in 0..(ts.size - 1)
          plrs << ts[i] / dsn_pwr.to_f
        end

        # Bin part load ratios
        pct_hrs_above_90 = bin_part_loads_by_ten_pcts(plrs)[9]

        # Check top-end part load ratio bins
        if ((pct_hrs_above_90 - expected_pct_hrs_above_90) / pct_hrs_above_90).abs > max_pct_delta
          check_elems << OpenStudio::Attribute.new('flag', "For #{equip.name}, the actual hrs above 90% part load of #{(pct_hrs_above_90 * 100).round(2)}% is more than #{(max_pct_delta * 100.0).round(2)}% different from the expected #{(expected_pct_hrs_above_90 * 100).round(2)}% of hrs above 90% part load.  This could indicate significantly oversized or undersized equipment.")
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
