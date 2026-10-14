require "simplecov"
require "codeclimate-test-reporter"

SimpleCov.use_merging true
SimpleCov.merge_timeout 3600
SimpleCov.add_filter '/test/'
SimpleCov.add_filter 'init.rb'
SimpleCov.formatters = []
SimpleCov.start(CodeClimate::TestReporter.configuration.profile) do
  root File.expand_path(File.dirname(__FILE__) + '/../../')
end

# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

class TestHelper
  def self.files_path
    File.dirname(__FILE__) + '/fixtures/'
  end
  def self.fixture_path
    if Redmine::VERSION::MAJOR >= 3
      File.dirname(__FILE__) + '/fixtures/3.0'
    else
      File.dirname(__FILE__) + '/fixtures/2.6'
    end
  end
end

class ActiveSupport::TestCase
  self.fixture_path = TestHelper.fixture_path
  # Redmine >= 5.1 declares "fixtures :all" for the core fixtures,
  # which do not exist in our fixture_path
  self.fixture_table_names = []
end
