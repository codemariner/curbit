module Curbit
  module Controller
    def self.included(controller)
      controller.extend ClassMethods
    end
    module ClassMethods

      # Establishes a before filter for the specified method that will limit
      # calls to it based on the given options:
      #
      # ==== Options
      # * +key+ - A symbol representing an instance method or Proc that will return the key used to identify calls. This is what is used to destinguish one call from another. If not specified, the client ip derived from the request will be used.  This will check for a HTTP_X_FORWARDED_FOR header first before using <tt>request.remote_addr</tt>.
      # * +max_calls+ - maximum number of calls allowed. Required.
      # * +time_limit+ - only :max_calls will be allowed within the specific time frame (in seconds).  If :max_calls is reached within this time, the call will be halted. Required.
      # * +wait_time+ - The time to wait if :max_calls has been reached before being able to pass.
      # * +message+ - The message to render to the client if the call is being limited.
      # * +status+ - The response status to set when the call is being limited.
      # * +render_format+ - The render format (e.g. :html, :json, :xml) for the message that will be returned on a limited call.
      #
      # ==== Examples
      #   rate_limit :invites, :key => :user_id, :max_calls => 5, :time_limit => 1.minute, :wait_time => 30.seconds
      #
      #   def user_id
      #     session[:user_id]
      #   end
      #
      # Example:
      # 
      # class InviteController < ApplicationController
      #   
      #   include Zap::Service
      #
      #   def validate
      #     # validate code
      #   end
      #
      #   rate_limit :validate, :key => Proc.new {
      #                                 key = params[:email].downcase if params[:email]
      #                               },
      #                        :max_calls => 10,
      #                        :time_limit => 1.minute,
      #                        :wait_time => 1.minute,
      #                        :message => '{"errors": [Too many attempts to validate your invitation code.  Please wait 1 minute before trying again."]}',
      #                        :status => 409,
      #                        :render_format => :json
      # end
      #
      def rate_limit(method, opts)

        validate_options(opts)

        self.class_eval do
          define_method "rate_limit_#{method}" do
            rate_limit_filter(method, opts)
          end
        end
        self.before_filter("rate_limit_#{method}", :only => method)
      end

      private 

      def validate_options(opts)
        raise ":max_calls must be defined" unless opts[:max_calls]
        raise ":time_limit must be defined" unless opts[:time_limit]
      end

    end

    private 

    def rate_limit_filter(method, opts)
      key = get_key(opts[:key])
      if (key == nil)
        return true
      end

      key = "curbit_rate_limit_key_#{key}"

      val = Rails.cache.read(key)

      if (val)
        started_at = val[:started]
        count = val[:count]
        val[:count] = count + 1
        started_waiting = val[:started_waiting]

        if started_waiting
          # did we exceed the wait time?
          if Time.now.to_i > (started_waiting.to_i + opts[:wait_time])
            Rails.cache.delete(key)
            return true
          else
            # should still wait, just fail
            render opts[:render_format] => opts[:message]
            return false
          end
        elsif within_time_limit? started_at, opts[:time_limit]
          # did we exceed max calls?
          if val[:count] > opts[:max_calls]
            val[:started_waiting] = Time.now
            Rails.cache.write(key, val, :expires_in => opts[:wait_time])

            message = opts[:message]
            if message
              if message.is_a? Proc
                respond_to do |format|
                  message.call(format)
                end
              elsif message.is_a? String
              end
            end

            render opts[:render_format] => opts[:message]
            return false
          else
            # just update the count
            Rails.cache.write(key, val, :expires_in => opts[:wait_time])
            return true
          end
        else
          # we exceeded the time limit, so just reset
          val = {:started => Time.now, :count => 1}
          Rails.cache.write(key, val, :expires_in => opts[:time_limit])
          return true
        end
      else
        val = {:started => Time.now, :count => 1}
        Rails.cache.write(key, val, :expires_in => opts[:time_limit])
      end
    end

    def within_time_limit?(started_at, limit)
      Time.now.to_i < (started_at.to_i + limit)
    end

    # attempts to get the key based on the given option or
    # will attempt to use the remote address
    def get_key(opt)
      key = nil
      if (opt)
        if opt.is_a? Proc
          key = opt.call()
        elsif opt.is_a? Symbol
          key = self.send(opt) if self.respond_to? opt
        end
      else
        if request.env('HTTP_X_FORWARDED_FOR') 
          key = request.env('HTTP_X_FORWARDED_FOR') 
        else
          key = request.remote_addr
        end
      end

      key
    end

  end
end
