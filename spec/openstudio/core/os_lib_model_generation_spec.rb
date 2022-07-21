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

require 'openstudio/extension/core/os_lib_helper_methods'
require 'openstudio/extension/core/os_lib_geometry'
require 'openstudio/extension/core/os_lib_model_generation'
require 'openstudio/extension/core/os_lib_model_simplification'
require 'openstudio-standards'

# adding this because I may want to inspect runner output
require 'openstudio/measure/ShowRunnerOutput'

# use this flag only when testing locally too turn of create_typical portion of tests when testing geometry generatioon
run_create_typical = true # should commit as true, only false for testing.

RSpec.describe 'Bar Methods' do # include from building type ratios, space type ratios, and from building
  context 'bar_from_empty' do
    before :each do
      # create an empty model
      @model = OpenStudio::Model::Model.new

      # setup climate zone, design days and epw (mimic critical elements of ChangeBuildingLocation measure)
      # this is needed for typical_building_from_model which uses CZ for construction and does a sizing run

      # set climate_zone
      climate_zone = 'ASHRAE 169-2013-5A' # this is for Boston weather file, hard coding vs. getting form stat file
      climate_zones = @model.getClimateZones
      climate_zones.setClimateZone('ASHRAE', climate_zone.gsub('ASHRAE 169-2013-', ''))

      # set epw file
      target_path = File.expand_path('../../files', File.dirname(__FILE__))
      epw_path = "#{target_path}/USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw"
      weather_file = @model.getWeatherFile
      weather_file.setString(10, epw_path)
      # not setting lat, long, elevation, etc for now, it will run but results may not be meaningful

      # add design days
      # todo - may be adding some unnecessary design days that slow the test down
      ddy_path = "#{target_path}/USA_MA_Boston-Logan.Intl.AP.725090_TMY3.ddy"
      ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_path).get
      ddy_model.getDesignDays.sort.each do |d|
        @model.addObject(d.clone)
      end

      # setting year will get rid of these warnings
      # [openstudio.model.YearDescription] <1> 'UseWeatherFile' is not yet a supported option for YearDescription
      @model.getYearDescription.setCalendarYear(2021)

      # create an instance of a runner with OSW
      target_path = File.expand_path('../../files', File.dirname(__FILE__))
      osw_path = OpenStudio::Path.new("#{target_path}/model_test.osw")
      osw = OpenStudio::WorkflowJSON.load(osw_path).get
      @runner = OpenStudio::Measure::OSRunner.new(osw)
    end

    # test bad argument
    # test bar_from_building_type_ratios method and typical_building_from_model
    # after geometry is created typical_building_from_model method is run on the resulting model
    it 'bad_args_bar_from_building_type_ratios runs' do
      # define the measure class for bar_from_building_type_ratios
      class BarFromBuildingTypeRatio_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('PrimarySchool'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(2.5); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(-0.5); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_d_fract_bldg_area', true); arg.setValue(0.0); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2004'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(50000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(3.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(1.5); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('Basements Ground Mid Top'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_building_type_ratios(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = BarFromBuildingTypeRatio_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_building_type_ratios method.'
      show_output(result)

      # confirm it failed and stopped with bad argument instead of running and getting ruby error
      expect(result.value.valueName).to eq 'Fail'
    end

    # test bar_from_building_type_ratios method and typical_building_from_model
    # after geometry is created typical_building_from_model method is run on the resulting model
    it 'bar_from_building_type_ratios runs' do
      # define the measure class for bar_from_building_type_ratios
      class BarFromBuildingTypeRatio_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('PrimarySchool'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_d_fract_bldg_area', true); arg.setValue(0.0); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2016'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(50000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(3.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(1.5); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('Basements Ground Mid Top'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_building_type_ratios(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = BarFromBuildingTypeRatio_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_building_type_ratios method.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_test_a1.osm")
      @model.save(output_file_path, true)

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'

      # define the measure class for typical_building_from_model
      class TypicalBuildingFromModel_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments
          #  need to include double and integer args so method to check doesnt fail,
          # try to dynamically create these in the future
          args = OpenStudio::Measure::OSArgumentVector.new

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2016'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('system_type', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_delivery_type', ['Forced Air'], true); arg.setValue('Forced Air'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('htg_src', ['NaturalGas'], true); arg.setValue('NaturalGas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('clg_src', ['Electricity'], true); arg.setValue('Electricity'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('swh_src', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('kitchen_makeup', ['Adjacent'], true); arg.setValue('Adjacent'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('exterior_lighting_zone', ['3 - All Other Areas'], true); arg.setValue('3 - All Other Areas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_constructions', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_space_type_loads', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_elevators', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_internal_mass', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exterior_lights', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('onsite_parking_fraction', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exhaust', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_swh', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_thermostat', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_hvac', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_refrigeration', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wkdy_op_hrs', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wknd_op_hrs', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('unmet_hours_tolerance', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_objects', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('enable_dst', true); arg.setValue(true); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = typical_building_from_model(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test_typical = TypicalBuildingFromModel_Test.new

      # get arguments
      arguments_typical = unit_test_typical.arguments(@model)
      argument_map_typical = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments_typical)

      if run_create_typical
        # run the unit_test
        unit_test_typical.run(@model, @runner, argument_map_typical)
        result_typical = @runner.result

        # show the output
        puts 'method results for typical_building_from_model method. This will also show output from earlier bar method'
        show_output(result_typical)

        # save the model to test output directory
        output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_typical_test_a2.osm")
        @model.save(output_file_path, true)
      end

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'
    end

    # test bar_from_space_type_ratios method
    it 'bar_from_space_type_ratios runs' do
      # define the measure class
      class BarFromSpaceTypeRatio_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments

          # this replaces arguments for building type a-d string and fraction (note, this isn't expecting same building type | space type combo twice and likley will not handle it well without additional code to account for it)
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_hash_string', true); arg.setValue('MediumOffice | MediumOffice - Conference => 0.2, PrimarySchool | Corridor => 0.125, PrimarySchool | Classroom => 0.175, Warehouse | Office => 0.5'); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2019'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(50000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(1.5); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('Basements Ground Mid Top'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_space_type_ratios(model, runner, user_arguments) # two additioonal arguments to this method when called by bar_from_building_type_ratios
        end
      end

      # get the measure (using measure beacuse these methods take in meaasure arguments)
      unit_test = BarFromSpaceTypeRatio_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_space_type_ratios method.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_space_type_ratios_test_b1.osm")
      @model.save(output_file_path, true)

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'

      # define the measure class for typical_building_from_model
      class TypicalBuildingFromModel_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments
          #  need to include double and integer args so method to check doesnt fail,
          # try to dynamically create these in the future
          args = OpenStudio::Measure::OSArgumentVector.new

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2019'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('system_type', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_delivery_type', ['Forced Air'], true); arg.setValue('Forced Air'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('htg_src', ['NaturalGas'], true); arg.setValue('NaturalGas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('clg_src', ['Electricity'], true); arg.setValue('Electricity'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('swh_src', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('kitchen_makeup', ['Adjacent'], true); arg.setValue('Adjacent'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('exterior_lighting_zone', ['3 - All Other Areas'], true); arg.setValue('3 - All Other Areas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_constructions', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_space_type_loads', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_elevators', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_internal_mass', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exterior_lights', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('onsite_parking_fraction', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exhaust', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_swh', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_thermostat', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_hvac', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_refrigeration', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wkdy_op_hrs', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wknd_op_hrs', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('hoo_var_method', true); arg.setValue('fractional'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('unmet_hours_tolerance', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_objects', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('enable_dst', true); arg.setValue(true); args << arg

          # new optional method argument that measures can add if they want load and use haystakc JSOn file
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('haystack_file', true); arg.setValue('SmallOffice_model.json'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = typical_building_from_model(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test_typical = TypicalBuildingFromModel_Test.new

      # get arguments
      arguments_typical = unit_test_typical.arguments(@model)
      argument_map_typical = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments_typical)

      if run_create_typical
        # run the unit_test
        unit_test_typical.run(@model, @runner, argument_map_typical)
        result_typical = @runner.result

        # show the output
        puts 'method results for typical_building_from_model method. This will also show output from earlier bar method'
        show_output(result_typical)

        # save the model to test output directory
        output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_space_type_ratios_typical_test_b2.osm")
        @model.save(output_file_path, true)
      end

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'
    end

    # test bar_from_space_type_ratios methodb
    it 'bar_from_space_type_ratios runs' do
      # define the measure class
      class BarFromSpaceTypeRatiob_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments

          # this replaces arguments for building type a-d string and fraction (note, this isn't expecting same building type | space type combo twice and likley will not handle it well without additional code to account for it)
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_hash_string', true); arg.setValue('MediumOffice | MediumOffice - Conference => 0.2, PrimarySchool | Corridor => 0.125, PrimarySchool | Classroom => 0.175, Warehouse | Office => 0.5'); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2019'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(50000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(1.5); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('Basements Ground Mid Top'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_space_type_ratios(model, runner, user_arguments) # two additioonal arguments to this method when called by bar_from_building_type_ratios
        end
      end

      # get the measure (using measure beacuse these methods take in meaasure arguments)
      unit_test = BarFromSpaceTypeRatiob_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_space_type_ratios method.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_space_type_ratios_test_b1b.osm")
      @model.save(output_file_path, true)

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'

      # define the measure class for typical_building_from_model
      class TypicalBuildingFromModelb_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments
          #  need to include double and integer args so method to check doesnt fail,
          # try to dynamically create these in the future
          args = OpenStudio::Measure::OSArgumentVector.new

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2019'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('system_type', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_delivery_type', ['Forced Air'], true); arg.setValue('Forced Air'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('htg_src', ['NaturalGas'], true); arg.setValue('NaturalGas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('clg_src', ['Electricity'], true); arg.setValue('Electricity'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('swh_src', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('kitchen_makeup', ['Adjacent'], true); arg.setValue('Adjacent'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('exterior_lighting_zone', ['3 - All Other Areas'], true); arg.setValue('3 - All Other Areas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_constructions', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_space_type_loads', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_elevators', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_internal_mass', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exterior_lights', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('onsite_parking_fraction', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exhaust', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_swh', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_thermostat', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_hvac', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_refrigeration', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wkdy_op_hrs', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wknd_op_hrs', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('unmet_hours_tolerance', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_objects', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('enable_dst', true); arg.setValue(true); args << arg

          # new optional method argument that measures can add if they want load and use haystakc JSOn file
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('haystack_file', true); arg.setValue('SmallOffice_model.json'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = typical_building_from_model(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test_typical = TypicalBuildingFromModelb_Test.new

      # get arguments
      arguments_typical = unit_test_typical.arguments(@model)
      argument_map_typical = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments_typical)

      if run_create_typical
        # run the unit_test
        unit_test_typical.run(@model, @runner, argument_map_typical)
        result_typical = @runner.result

        # show the output
        puts 'method results for typical_building_from_model method. This will also show output from earlier bar method'
        show_output(result_typical)

        # save the model to test output directory
        output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_space_type_ratios_typical_test_b2b.osm")
        @model.save(output_file_path, true)
      end

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'
    end

    # test hospital model with intersection issues
    # test bar_from_building_type_ratios method and typical_building_from_model
    it 'bar_from_building_type_ratios_hos_intersect_test runs' do
      # define the measure class for bar_from_building_type_ratios
      class BarFromBuildingTypeRatioHosInt_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('Hospital'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_d_fract_bldg_area', true); arg.setValue(0); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2013'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(10000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(11145.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(10.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(0); args << arg # also fails in different way if use 1.5
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(10.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('None'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_building_type_ratios(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = BarFromBuildingTypeRatioHosInt_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_building_type_ratios method with hospital inputs that results in error related to intersection.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_hos_intersect.osm")
      @model.save(output_file_path, true)

      # confirm it failed and stopped with bad argument instead of running and getting ruby error
      expect(result.value.valueName).to eq 'Success'
    end

    # test hospital model with intersection issues
    # test bar_from_building_type_ratios method and typical_building_from_model
    # same as bar_from_building_type_ratios_hos_intersect_test but not using make_mid_story_surfaces_adiabatic
    it 'bar_from_building_type_ratios_hos_intersect2_test runs' do
      skip 'is skipped'
      # define the measure class for bar_from_building_type_ratios
      class BarFromBuildingTypeRatioHosInt2_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('Hospital'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_d_fract_bldg_area', true); arg.setValue(0); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2013'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(10000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(11145.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(10.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(10.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('None'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_building_type_ratios(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = BarFromBuildingTypeRatioHosInt2_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_building_type_ratios method with hospital inputs that results in error related to intersection.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_hos_intersect2.osm")
      @model.save(output_file_path, true)

      # confirm it failed and stopped with bad argument instead of running and getting ruby error
      expect(result.value.valueName).to eq 'Success'
    end

    # test hospital model with intersection issues
    # test bar_from_building_type_ratios method and typical_building_from_model
    # same as bar_from_building_type_ratios_hos_intersect_test but using custom perim_mult value
    # fix foor this is like in make_sliced_bar_multi_polygons method in os_lib_geometry
    it 'bar_from_building_type_ratios_hos_intersect3_test runs' do
      # define the measure class for bar_from_building_type_ratios
      class BarFromBuildingTypeRatioHosInt3_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('Hospital'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_d_fract_bldg_area', true); arg.setValue(0); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2013'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(10000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(11145.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(10.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(2.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(1.5); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('None'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_building_type_ratios(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = BarFromBuildingTypeRatioHosInt3_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_building_type_ratios method with hospital inputs that results in error related to space type ratios.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_hos_intersect3.osm")
      @model.save(output_file_path, true)

      # confirm it failed and stopped with bad argument instead of running and getting ruby error
      expect(result.value.valueName).to eq 'Success'
    end

    # test retail_standalone
    it 'bar_from_building_type_ratios_retail_standalone_test runs' do
      # define the measure class for bar_from_building_type_ratios
      class BarFromBuildingTypeRatioHosInt3_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('RetailStandalone'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_d_fract_bldg_area', true); arg.setValue(0); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2004'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(10000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(10.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('None'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_building_type_ratios(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = BarFromBuildingTypeRatioHosInt3_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_building_type_ratios method with retail_standalone inputs that results in missing internal loads with OpenStudio 3.4.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_retail_standalone_1.osm")
      @model.save(output_file_path, true)

      # confirm it failed and stopped with bad argument instead of running and getting ruby error
      expect(result.value.valueName).to eq 'Success'

      # define the measure class for typical_building_from_model
      class TypicalBuildingFromModel_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments
          #  need to include double and integer args so method to check doesnt fail,
          # try to dynamically create these in the future
          args = OpenStudio::Measure::OSArgumentVector.new

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2004'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('system_type', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_delivery_type', ['Forced Air'], true); arg.setValue('Forced Air'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('htg_src', ['NaturalGas'], true); arg.setValue('NaturalGas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('clg_src', ['Electricity'], true); arg.setValue('Electricity'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('swh_src', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('kitchen_makeup', ['Adjacent'], true); arg.setValue('Adjacent'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('exterior_lighting_zone', ['3 - All Other Areas'], true); arg.setValue('3 - All Other Areas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_constructions', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_space_type_loads', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_elevators', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_internal_mass', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exterior_lights', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('onsite_parking_fraction', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exhaust', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_swh', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_thermostat', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_hvac', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_refrigeration', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wkdy_op_hrs', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wknd_op_hrs', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('unmet_hours_tolerance', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_objects', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('enable_dst', true); arg.setValue(true); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = typical_building_from_model(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test_typical = TypicalBuildingFromModel_Test.new

      # get arguments
      arguments_typical = unit_test_typical.arguments(@model)
      argument_map_typical = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments_typical)

      if run_create_typical
        # run the unit_test
        unit_test_typical.run(@model, @runner, argument_map_typical)
        result_typical = @runner.result

        # show the output
        puts 'method results for typical_building_from_model method. This will also show output from earlier bar method'
        show_output(result_typical)

        # save the model to test output directory
        output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_retail_standalone_2.osm")
        @model.save(output_file_path, true)
      end

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'
    
    end

    # test retail_stripmall
    it 'bar_from_building_type_ratios_retail_stripmall_test runs' do
      # define the measure class for bar_from_building_type_ratios
      class BarFromBuildingTypeRatioHosInt3_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # all but 4-5 of these to have defaults so full set of arguments
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('RetailStripmall'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('SmallOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_d_fract_bldg_area', true); arg.setValue(0); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2004'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('total_bldg_floor_area', true); arg.setValue(10000.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('single_floor_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('floor_height', true); arg.setValue(10.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('num_stories_above_grade', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('num_stories_below_grade', true); arg.setValue(0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('building_rotation', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('ns_to_ew_ratio', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('perim_mult', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_width', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bar_sep_dist_mult', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wwr', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('party_wall_fraction', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_north', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_south', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_east', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('party_wall_stories_west', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('custom_height_bar', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('bottom_story_ground_exposed_floor', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('top_story_exterior_exposed_roof', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('make_mid_story_surfaces_adiabatic', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('story_multiplier', true); arg.setValue('None'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('bar_division_method', true); arg.setValue('Multiple Space Types - Individual Stories Sliced'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('double_loaded_corridor', true); arg.setValue('Primary Space Type'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_sort_logic', true); arg.setValue('Building Type > Size'); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = bar_from_building_type_ratios(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = BarFromBuildingTypeRatioHosInt3_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for bar_from_building_type_ratios method with retail_stripmall inputs that results in missing internal loads with OpenStudio 3.4.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_retail_stripmall_1.osm")
      @model.save(output_file_path, true)

      # confirm it failed and stopped with bad argument instead of running and getting ruby error
      expect(result.value.valueName).to eq 'Success'

      # define the measure class for typical_building_from_model
      class TypicalBuildingFromModel_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)
          # create arguments
          #  need to include double and integer args so method to check doesnt fail,
          # try to dynamically create these in the future
          args = OpenStudio::Measure::OSArgumentVector.new

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2004'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('system_type', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_delivery_type', ['Forced Air'], true); arg.setValue('Forced Air'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('htg_src', ['NaturalGas'], true); arg.setValue('NaturalGas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('clg_src', ['Electricity'], true); arg.setValue('Electricity'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('swh_src', ['Inferred'], true); arg.setValue('Inferred'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('kitchen_makeup', ['Adjacent'], true); arg.setValue('Adjacent'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('exterior_lighting_zone', ['3 - All Other Areas'], true); arg.setValue('3 - All Other Areas'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_constructions', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_space_type_loads', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_elevators', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_internal_mass', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exterior_lights', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('onsite_parking_fraction', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_exhaust', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_swh', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_thermostat', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_hvac', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_refrigeration', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wkdy_op_hrs', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wkdy_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('modify_wknd_op_hrs', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_start_time', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('wknd_op_hrs_duration', true); arg.setValue(8.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('unmet_hours_tolerance', true); arg.setValue(1.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_objects', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('use_upstream_args', true); arg.setValue(false); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('enable_dst', true); arg.setValue(true); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = typical_building_from_model(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test_typical = TypicalBuildingFromModel_Test.new

      # get arguments
      arguments_typical = unit_test_typical.arguments(@model)
      argument_map_typical = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments_typical)

      if run_create_typical
        # run the unit_test
        unit_test_typical.run(@model, @runner, argument_map_typical)
        result_typical = @runner.result

        # show the output
        puts 'method results for typical_building_from_model method. This will also show output from earlier bar method'
        show_output(result_typical)

        # save the model to test output directory
        output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/bar_from_building_type_ratios_retail_stripmall_2.osm")
        @model.save(output_file_path, true)
      end

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'      

    end

    # wizard_test_retail_standalone
    it 'wizard_test_retail_standalone runs' do
      skip 'is skipped' # remove skip when https://github.com/NREL/openstudio-standards/issues/1343 fix is in installer.
      # define the measure class for wizard
      class SpaceTypeAndConstructionSetWizard_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_ModelGeneration

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('building_type', get_doe_building_types, true); arg.setValue('RetailStandalone'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2004'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('climate_zone', get_doe_climate_zones(true), true); arg.setValue('ASHRAE 169-2013-5A'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('create_space_types', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('create_construction_set', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('set_building_defaults', true); arg.setValue(true); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = wizard(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = SpaceTypeAndConstructionSetWizard_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for wizard method on RetailStandalone.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/wizard_retail_standalone.osm")
      @model.save(output_file_path, true)

      # confirm it worked and is populated with internal loads
      expect(result.value.valueName).to eq 'Success'
      expect(result.warnings.size).to eq 0
    end

    # wizard_test_retail_stripmall
    it 'wizard_test_retail_stripmall runs' do
      # define the measure class for wizard
      class SpaceTypeAndConstructionSetWizard_Test < OpenStudio::Measure::ModelMeasure
        # resource file modules
        include OsLib_HelperMethods
        include OsLib_ModelGeneration

        # define the arguments that the user will input
        def arguments(model)
          # create arguments`
          args = OpenStudio::Measure::OSArgumentVector.new
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('building_type', get_doe_building_types, true); arg.setValue('RetailStripmall'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2007'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('climate_zone', get_doe_climate_zones(true), true); arg.setValue('ASHRAE 169-2013-5A'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('create_space_types', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('create_construction_set', true); arg.setValue(true); args << arg
          arg = OpenStudio::Measure::OSArgument.makeBoolArgument('set_building_defaults', true); arg.setValue(true); args << arg

          return args
        end

        # define what happens when the measure is run
        def run(model, runner, user_arguments)
          # method run from os_lib_model_generation.rb
          result = wizard(model, runner, user_arguments)
        end
      end

      # get the measure (using measure beacuse these methods take in measure arguments)
      unit_test = SpaceTypeAndConstructionSetWizard_Test.new

      # get arguments
      arguments = unit_test.arguments(@model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

      # run the unit_test
      unit_test.run(@model, @runner, argument_map)
      result = @runner.result

      # show the output
      puts 'method results for wizard method on RetailStripmall.'
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/output/wizard_retail_stripmall.osm")
      @model.save(output_file_path, true)

      # confirm it worked and is populated with internal loads
      expect(result.value.valueName).to eq 'Success'
      expect(result.warnings.size).to eq 0
    end

  end

  # TODO: - add context with bar from non empty or running bar methods twice on same model
end
