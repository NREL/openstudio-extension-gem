require_relative '../spec_helper'

RSpec.describe OpenStudio::GEM_CLASS_NAME do
  it 'has a version number' do
    expect(OpenStudio::GEM_CLASS_NAME::VERSION).not_to be nil
  end

  it 'has a measures directory' do
    instance = OpenStudio::GEM_CLASS_NAME::GEM_CLASS_NAME.new
    expect(File.exist?(instance.measures_dir)).to be true
  end
end
