# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# TODO: should we load all this files when we require 'openstudio/extension'? I vote yes, but have to be careful with
# conflicts.
require 'openstudio/extension/core/os_lib_geometry'

RSpec.describe 'OS Lib Geometry' do
  context 'z-values' do
    before :all do
      @model = OpenStudio::Model.exampleModel
    end

    it 'should find all z values' do
      surfaces = []
      @model.getSurfaces.each do |surface|
        surfaces << surface
      end

      res = OsLib_Geometry.getSurfaceZValues(surfaces)
      expect(res.max).to eq 3.0
      expect(res.min).to eq 0
      expect(res.length).to eq 96
    end
  end
end
