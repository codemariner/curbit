require 'test_helper'
require 'test_rails_helper'

class MessageController < ActionController::Base

  include Curbit::Controller

  attr_accessor :rendered

  def index
    render :text => 'index action'
  end

  rate_limit :index, :max_calls => 2,
                     :time_limit => 30.seconds,
                     :wait_time => 2.minute,
                     :message => :limit_message

  protected

  def limit_message(wait_time)
    respond_to {|format|
      message = "Please wait #{wait_time/60} minutes before trying again"
      format.html {
        render :text => message, :status => 103
      }
      format.json {
        render :json => %[{"error":"#{message}"}], :status => 503
      }
    }
  end

end


class MessageControllerTest < ActionController::TestCase
  tests MessageController

  context "When calling a rate limited method using a message value of a" do
    setup {
      @env = {'HTTP_X_FORWARDED_FOR' => '192.168.1.123'}
      @request.stubs(:env).returns(@env)
      cache_value = {:started => Time.now.to_i - 15.seconds,
                     :count => 2
                     }
      Rails.cache.stubs(:read).returns(cache_value)
      Rails.cache.stubs(:write)
    }
    context "symbol" do
      context "for a json request format, it" do
        should "call a method named by the symbol with the specified wait_time" do
          get :index, :format => "json"
          assert_equal true, @response.body.include?("error") 
          assert_equal "503 Service Unavailable", @response.status
        end
      end

      context "and an html request format, it" do
        should "call a method named by the symbol with the specified wait_time" do
          get :index
          assert_equal true, @response.body.include?("wait") 
          assert_equal "103", @response.status
        end
      end
    end

  end
end

