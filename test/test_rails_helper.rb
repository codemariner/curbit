# rails setup
ENV["RAILS_ENV"] = "test"
RAILS_ROOT = "wherever"

require 'active_support'
require 'action_controller'
require 'action_controller/test_case'
require 'action_controller/test_process'


class ApplicationController < ActionController::Base; end


# add curbit to load path and init
ActiveSupport::Dependencies.load_paths << File.expand_path(File.dirname(__FILE__) + '/../lib')
require_dependency 'curbit'


ActionController::Base.view_paths = File.join(File.dirname(__FILE__), 'views')
ActionController::Routing::Routes.draw do |map|
    map.connect ':controller/:action/:id'
end

require 'ostruct'

# stub out a rails cache object
Rails = OpenStruct.new

Rails.logger = Logger.new("/dev/null")
