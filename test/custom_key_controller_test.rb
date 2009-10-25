require 'test_helper'
require 'test_rails_helper'

class MethodController < ActionController::Base

  include Curbit::Controller

  def index
    render :text => 'index action'
  end

  rate_limit :index, :key => :username,
                     :max_calls => 2,
                     :time_limit => 30.seconds,
                     :wait_time => 1.minute

  def show
    render :text => 'show action'
  end

  rate_limit :show, :key => proc {|c| "my_key"},
                    :max_calls => 2,
                    :time_limit => 30.seconds,
                    :wait_time => 1.minute

  protected

  def username
    "codemariner"
  end

end


class MethodControllerTest < ActionController::TestCase
  tests MethodController

  context "When calling a rate_limited method with a key argument that is a symbol it" do
    setup {
      Rails.cache = mock()
      @env = {'HTTP_X_FORWARDED_FOR' => '192.168.1.123'}
      @request.stubs(:env).returns(@env)
      Rails.cache.stubs(:write)
    }
    should "call the specified method to use as part of the cache key" do
      Rails.cache.expects(:read).with(Curbit::Controller::CacheKeyPrefix + "_#{MethodController.name}_index_codemariner").at_least_once
      get :index
      assert_equal "index action", @response.body
    end
  end

  context "When calling a rate_limited method with a key argument that is a Proc it" do
    setup {
      Rails.cache = mock()
      @env = {'HTTP_X_FORWARDED_FOR' => '192.168.1.123'}
      @request.stubs(:env).returns(@env)
      Rails.cache.stubs(:write)
    }
    should "call the Proc to use the returned value as part of the cache key" do
      Rails.cache.expects(:read).with(Curbit::Controller::CacheKeyPrefix + "_#{MethodController.name}_show_my_key").at_least_once
      get :show
      assert_equal "show action", @response.body
    end
  end
end

