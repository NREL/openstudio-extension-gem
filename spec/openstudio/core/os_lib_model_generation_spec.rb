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

RSpec.describe 'Bar Methods' do # include from building type ratios, space type ratios, and from building
  context 'bar_from_empty' do
    before :each do

      # create an empty model
      @model = OpenStudio::Model::Model.new

      # create a runner
      @runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    end

    # test bar_from_building_type_ratios method
    it 'bar_from_building_type_ratios runs' do

      # start the measure
      class BarFromBuildingTypeRatio_Test < OpenStudio::Measure::ModelMeasure

        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)

          # create agruments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # todo - update all but 4-5 of these to have defaults so full set of arguments doesn't have to be passed in to the method
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_a', get_doe_building_types, true); arg.setValue('PrimarySchool'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_b', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_c', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('bldg_type_d', get_doe_building_types, true); arg.setValue('MediumOffice'); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_b_fract_bldg_area', true); arg.setValue(0.0); args << arg
          arg = OpenStudio::Measure::OSArgument.makeDoubleArgument('bldg_type_c_fract_bldg_area', true); arg.setValue(0.0); args << arg
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
      puts "method results for bar_from_building_type_ratios method."
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/bar_from_building_type_ratios_test_a.osm")
      @model.save(output_file_path, true)

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'

    end

    # test bar_from_space_type_ratios method
    it 'bar_from_space_type_ratios runs' do

      # start the measure
      class BarFromSpaceTypeRatio_Test < OpenStudio::Measure::ModelMeasure

        # resource file modules
        include OsLib_HelperMethods
        include OsLib_Geometry
        include OsLib_ModelGeneration
        include OsLib_ModelSimplification

        # define the arguments that the user will input
        def arguments(model)

          # create agruments`
          args = OpenStudio::Measure::OSArgumentVector.new
          # todo - update all but 4-5 of these to have defaults so full set of arguments doesn't have to be passed in to the method

          # this replaces arguemnts for building type a-d string and fraction (note, this isn't expecting same building type | space type combo twice and likley will not handle it well without additinoal code to account for it)
          arg = OpenStudio::Measure::OSArgument.makeStringArgument('space_type_hash_string', true); arg.setValue("MediumOffice | Conference => 0.2, PrimarySchool | Corridor => 0.125, PrimarySchool | Classroom => 0.175, Warehouse | Office => 0.5"); args << arg

          arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_doe_templates(true), true); arg.setValue('90.1-2013'); args << arg
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
          result = bar_from_space_type_ratios(model, runner, user_arguments) # to additinal arguments to this method when called by bar_from_building_type_ratios
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
      puts "method results for bar_from_space_type_ratios method."
      show_output(result)

      # save the model to test output directory
      output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/bar_from_space_type_ratios_test_a.osm")
      @model.save(output_file_path, true)

      # confirm it ran correctly
      expect(result.value.valueName).to eq 'Success'

    end

  end

  # todo - add context with bar from non empty or running bar methods twice on same model

end
