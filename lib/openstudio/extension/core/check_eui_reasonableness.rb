# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module OsLib_QAQC
  # include any general notes about QAQC method here

  # checks the number of unmet hours in the model
  def check_eui_reasonableness(category, target_standard, min_pass, max_pass, name_only = false)
    # summary of the check
    check_elems = OpenStudio::AttributeVector.new
    check_elems << OpenStudio::Attribute.new('name', 'EUI Reasonableness')
    check_elems << OpenStudio::Attribute.new('category', category)
    check_elems << OpenStudio::Attribute.new('description', "Check EUI for model against #{target_standard} DOE prototype buildings.")

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
      # total building area
      query = 'SELECT Value FROM tabulardatawithstrings WHERE '
      query << "ReportName='AnnualBuildingUtilityPerformanceSummary' and "
      query << "ReportForString='Entire Facility' and "
      query << "TableName='Building Area' and "
      query << "RowName='Total Building Area' and "
      query << "ColumnName='Area' and "
      query << "Units='m2';"
      query_results = @sql.execAndReturnFirstDouble(query)
      if query_results.empty?
        check_elems << OpenStudio::Attribute.new('flag', "Can't calculate EUI, SQL query for building area failed.")
        return OpenStudio::Attribute.new('check', check_elems)
      else
        energy_plus_area = query_results.get
      end

      # temp code to check OS vs. E+ area
      open_studio_area = @model.getBuilding.floorArea
      if (energy_plus_area - open_studio_area).abs >= 0.1
        check_elems << OpenStudio::Attribute.new('flag', "EnergyPlus reported area is #{energy_plus_area} (m^2). OpenStudio reported area is #{@model.getBuilding.floorArea} (m^2).")
      end

      # EUI
      source_units = 'GJ/m^2'
      target_units = 'kBtu/ft^2'
      if energy_plus_area > 0.0 # don't calculate EUI if building doesn't have any area
        # todo -  netSiteEnergy deducts for renewable. May want to update this to show gross consumption vs. net consumption
        eui = @sql.netSiteEnergy.get / energy_plus_area
      else
        check_elems << OpenStudio::Attribute.new('flag', "Can't calculate model EUI, building doesn't have any floor area.")
        return OpenStudio::Attribute.new('check', check_elems)
      end

      # test using new method
      if use_old_gem_code
        target_eui = @model.find_target_eui(target_standard)
      else
        std = Standard.build(target_standard)
        target_eui = std.model_find_target_eui(@model)
      end

      # check model vs. target for user specified tolerance.
      if !target_eui.nil?
        eui_ip_neat = OpenStudio.toNeatString(OpenStudio.convert(eui, source_units, target_units).get, 1, true)
        target_eui_ip_neat = OpenStudio.toNeatString(OpenStudio.convert(target_eui, source_units, target_units).get, 1, true)
        if eui < target_eui * (1.0 - min_pass)
          check_elems << OpenStudio::Attribute.new('flag', "Model EUI of #{eui_ip_neat} (#{target_units}) is less than #{min_pass * 100} % below the expected EUI of #{target_eui_ip_neat} (#{target_units}) for #{target_standard}.")
        elsif eui > target_eui * (1.0 + max_pass)
          check_elems << OpenStudio::Attribute.new('flag', "Model EUI of #{eui_ip_neat} (#{target_units}) is more than #{max_pass * 100} % above the expected EUI of #{target_eui_ip_neat} (#{target_units}) for #{target_standard}.")
        end
      else
        check_elems << OpenStudio::Attribute.new('flag', "Can't calculate target EUI. Make sure model has expected climate zone and building type.")
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
