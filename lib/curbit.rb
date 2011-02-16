module Curbit
  module Controller

    CacheKeyPrefix = "crl_key"

    def self.included(controller)
      controller.extend ClassMethods
    end

    module ClassMethods


      # Establishes a before filter for the specified method that will limit
      # calls to it based on the given options:
      #
      # ==== Options
        # * +key+ - A symbol representing an instance method or Proc that will return the key used to identify calls. This is what is used to destinguish one call from another. If not specified, the client ip derived from the request will be used.  This will check for a HTTP_X_FORWARDED_FOR header first before using <tt>request.remote_addr</tt>.  The Proc will be passed the controller instance as it is out of scope when the Proc is initially created (so you can get at request, params, etc.).
      # * +max_calls+ - maximum number of calls allowed. Required.
      # * +time_limit+ - only :max_calls will be allowed within the specific time frame (in seconds).  If :max_calls is reached within this time, the call will be halted. Required.
      # * +wait_time+ - The time to wait if :max_calls has been reached before being able to pass.
      # * +message+ - The message to render to the client if the call is being limited.  The message will be rendered as a correspondingly formatted response with a default status if given a String.  If the argument is a symbol, a method with the same name will be invoked with the specified wait_time (in seconds).  The called method should take care of rendering the response.
      # * +status+ - The response status to set when the call is being limited.
      # * +if+ - A symbol representing a method or Proc that returns true if the rate limiting should be applied.
      # * +unless+ - A symbol representing a method or Proc that returns true if the rate limiting should NOT be applied.
      #
      # ==== Examples
      # 
      # class InviteController < ApplicationController
      #   
      #   include Curbit::Controller
      #
      #   def validate
      #     # validate code
      #   end
      #
      #   rate_limit :validate, :max_calls => 10,
      #                         :time_limit => 1.minute,
      #                         :wait_time => 1.minute,
      #                         :message => 'Too many attempts to validate your invitation code.  Please wait 1 minute before trying again.'
      #
      #
      #   def invite
      #     # invite code
      #   end
      #
      #   rate_limit :invite, :key => proc {|c| c.session[:userid]},
      #                        :max_calls => 2,
      #                        :time_limit => 30.seconds,
      #                        :wait_time => 1.minute
      # end
      #
      def rate_limit(method, opts)

        return unless rate_limit_opts_valid?(opts)

        self.class_eval do
          define_method "rate_limit_#{method}" do
            rate_limit_filter(method, opts)
          end
        end
        self.before_filter("rate_limit_#{method}", :only => method)
      end

      private 

      def rate_limit_opts_valid?(opts = {})
        new_opts = {:status => 503}.merge! opts
        opts.merge! new_opts
        if opts.key?(:if) and opts.key?(:unless)
          raise ":unless and :if are mutually exclusive parameters"
        end
        if !opts.key?(:max_calls) or !opts.key?(:time_limit) or !opts.key?(:wait_time)
          raise ":max_calls, :time_limit, and :wait_time are required parameters"
        end
        true
      end
    end
    
    private
    
    def write_to_curbit_cache(cache_key, value, options = {})
      Rails.cache.write(cache_key, value, options)
    end
    
    def read_from_curbit_cache(cache_key)
      Rails.cache.read(cache_key)
    end
    
    def delete_from_curbit_cache(cache_key)
      Rails.cache.delete(cache_key)
    end

    def curbit_cache_key(key, method)
      # TODO: this won't work if there are more than one controller with
      # the same name in the same app
      "#{CacheKeyPrefix}_#{self.class.name}_#{method}_#{key}"
    end

    def rate_limit_conditional(opts)
      if opts.key?(:unless)
       if opts[:unless].is_a? Proc
         return true if opts[:unless].call(self)
       elsif opts[:unless].is_a? Symbol
         return true if self.send(opts[:unless])
        end
      end
      if opts.key?(:if)
       if opts[:if].is_a? Proc
         return true unless opts[:if].call(self)
       elsif opts[:if].is_a? Symbol
         return true unless self.send(opts[:if])
        end
      end
      return false
    end

    def rate_limit_filter(method, opts)

      return true if rate_limit_conditional(opts)

      key = get_key(opts[:key])
      unless (key)
        return true
      end

      cache_key = curbit_cache_key(key, method)

      val = read_from_curbit_cache(cache_key)

      if (val)
        val = val.dup
        started_at = val[:started]
        count = val[:count]
        val[:count] = count + 1
        started_waiting = val[:started_waiting]

        # did we start making the user wait before being allowed to make
        # another call?
        if started_waiting
          # did we exceed the wait time?
          if Time.now.to_i > (started_waiting.to_i + opts[:wait_time])
            delete_from_curbit_cache(cache_key)
            return true
          else
            get_message(opts)
            return false
          end
        elsif within_time_limit? started_at, opts[:time_limit]
          # did we exceed max calls?
          if val[:count] > opts[:max_calls]
            # start waiting and render the message
            val[:started_waiting] = Time.now
            write_to_curbit_cache(cache_key, val, :expires_in => opts[:wait_time])

            get_message(opts)

            return false
          else
            # just update the count
            write_to_curbit_cache(cache_key, val, :expires_in => opts[:wait_time])
            return true
          end
        else
          # we exceeded the time limit, so just reset
          val = {:started => Time.now, :count => 1}
          write_to_curbit_cache(cache_key, val, :expires_in => opts[:time_limit])
          return true
        end
      else
        val = {:started => Time.now, :count => 1}
        write_to_curbit_cache(cache_key, val, :expires_in => opts[:time_limit])
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
          key = opt.call(self) # passing it the controller instance
        elsif opt.is_a? Symbol
          key = self.send(opt) if self.respond_to? opt
        end
      else
        if request.env['HTTP_X_FORWARDED_FOR'] 
          key = request.env['HTTP_X_FORWARDED_FOR'] 
        else
          addr = request.remote_addr
          if (addr == "0.0.0.0" or addr == "127.0.0.1")
            Rails.logger.warn "attempting to rate limit with a localhost address.  Ignoring."
            return nil
          else
            key = addr
          end
        end
      end

      key
    end

    def get_message(opts)
      message = opts[:message]
      if message
        if message.is_a? Proc
          respond_to do |format|
            message.call(self, opts[:wait_time])
          end
        elsif message.is_a? Symbol
          self.send(message, opts[:wait_time])
        elsif message.is_a? String
          render_curbit_message(message, opts)
        end
      else
        message = "Too many requests within the allowed time.  Please wait #{opts[:wait_time]} seconds before submitting your request again."
        render_curbit_message(message, opts)
      end
    end

    def render_curbit_message(message, opts)
      rendered = false
      respond_to {|format|
          format.html {
            render :text => message, :status => opts[:status]
            rendered = true
          }
          format.json {
            render :json => %[{"error":"#{message}"}], :status => opts[:status]
            rendered = true
          }
          format.xml {
            render :xml => "<error>#{message}</error>", :status => opts[:status]
            rendered = true
          }
      }
      if (!rendered)
        render :text => message, :status => opts[:status]
      end
    end

  end
end
