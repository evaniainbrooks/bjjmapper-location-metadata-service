require 'test/unit'
require 'mocha/test_unit'

Dir['test/**/*_test.rb'].each { |testCase| require "./#{testCase}" }

