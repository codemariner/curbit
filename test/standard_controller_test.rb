require 'test_helper'
require 'test_rails_helper'

class TestController < ActionController::Base

  include Curbit::Controller

  def index
    render :text => 'index action'
  end

  rate_limit :index, :max_calls => 2,
                     :time_limit => 30.seconds,
                     :wait_time => 1.minute

  def show
    render :text => 'show action'
  end

  rate_limit :show, :max_calls => 2,
                    :time_limit => 30.seconds,
                    :wait_time => 1.minute,
                    :status => 200
end


class CurbiControllerTest < ActionController::TestCase
  tests TestController

  context "A controller including Curbit" do
    should "have a rate_limit class method" do
      assert_equal true, TestController.respond_to?(:rate_limit)
    end
  end

  context "When declaring a rate_limit method, there " do
      should "be a new rate_limit_method method added to the instance" do
          assert_equal true, @controller.respond_to?(:rate_limit_index)
      end
  end

  context "When calling a rate_limited method" do
    setup {
      Rails.cache = mock()
    }

    context "without a designated key argument" do
      context "and the remote client address is forwarded from a proxy, it" do
        setup {
          @env = {'HTTP_X_FORWARDED_FOR' => '192.168.1.123'}
          @request.stubs(:env).returns(@env)
          @cache_key = nil
          Rails.cache.expects(:write).with() {|key, val, duration|
            @cache_key = key
            true
          }
          Rails.cache.expects(:read).returns(nil)
        }

        should "use a default key that is derived from request.env['HTTP_X_FORWARDED_FOR']" do
          get :index
          ip = @env['HTTP_X_FORWARDED_FOR']
          pfx = Curbit::Controller::CacheKeyPrefix
          assert_equal "#{pfx}_#{TestController.name}_index_#{ip}", @cache_key
        end
      end #context: and the remote client address is...


      context "and the remote client address is a localhost address, it" do
        setup {
          @request.stubs(:remote_addr).returns("0.0.0.0")
          Rails.cache.expects(:read).never()
        }
        should "ignore rate limiting" do
          get :index
          assert_equal "index action", @response.body
        end
      end

    end #context: without a designated key argument...

    context "from a remote client" do
      setup {
        @env = {'HTTP_X_FORWARDED_FOR' => '192.168.1.123'}
        @request.stubs(:env).returns(@env)
      }
      context "and max calls has been exceeded for the current time limit" do
        setup {
          # emulate the state needed to indicate that we've started
          # waiting on calls
          cache_value = {:started => Time.now.to_i - 15.seconds,
                         :count => 1
                         }
          Rails.cache.stubs(:read).returns(cache_value)
          Rails.cache.stubs(:write).with() {|key, val, duration|
            cache_value[:count] = val[:count]
            true;
          }
        }
        context ", the call" do
          should "be blocked" do
            get :index
            assert_equal "index action", @response.body
            get :index
            assert_equal true, @response.body.include?("wait")
            # default status on a limit
            assert_equal "503 Service Unavailable", @response.status
          end

          should "be blocked and render a custom status when specified" do
            get :show
            assert_equal "show action", @response.body
            get :show
            assert_equal true, @response.body.include?("wait")
            # default status on a limit
            assert_equal "200 OK", @response.status
          end
        end
      end
    end

  end #context: when calling a rate limited method...

end
