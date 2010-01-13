require 'test_helper'
require 'test_rails_helper'

class ConditionalController < ActionController::Base

  include Curbit::Controller

  attr_accessor :rendered

  def index
    render :text => 'index action'
  end

  def show
    render :text => 'show action'
  end

  rate_limit :index, :max_calls => 2,
                     :time_limit => 30.seconds,
                     :wait_time => 2.minute,
                     :if => :logged_in?

  rate_limit :show,  :max_calls => 2,
                     :time_limit => 30.seconds,
                     :wait_time => 2.minute,
                     :unless => :logged_in?


  protected

  def logged_in?
    true
  end

end


class ConditionalControllerTest < ActionController::TestCase
  tests ConditionalController

  context "When calling a rate limited method with " do
    setup {
      @env = {'HTTP_X_FORWARDED_FOR' => '192.168.1.123'}
      @request.stubs(:env).returns(@env)
      cache_value = {:started => Time.now.to_i - 15.seconds,
                     :count => 2
                     }
      Rails.cache.stubs(:read).returns(cache_value)
      Rails.cache.stubs(:write)
    }
    context ":if, it" do
        should "should call a method named by the symbol" do
          get :index
          assert_equal "503 Service Unavailable", @response.status
        end
    end
     context ":unless, it" do
        should "should call a method named by the symbol" do
          get :show
          assert_equal "show action", @response.body
        end
    end
   

  end
end

