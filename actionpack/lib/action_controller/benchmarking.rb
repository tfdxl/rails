require 'benchmark'

module ActionController #:nodoc:
  # The benchmarking module times the performance of actions and reports to the logger. If the Active Record
  # package has been included, a separate timing section for database calls will be added as well.
  module Benchmarking #:nodoc:
    def self.append_features(base)
      super
      base.class_eval {
        alias_method :perform_action_without_benchmark, :perform_action
        alias_method :perform_action, :perform_action_with_benchmark

        alias_method :render_without_benchmark, :render
        alias_method :render, :render_with_benchmark
      }
    end

    def render_with_benchmark(template_name = default_template_name, status = "200 OK")
      if logger.nil?
        render_without_benchmark(template_name, status)
      else
        db_runtime = ActiveRecord::Base.connection.reset_runtime if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
        @rendering_runtime = Benchmark::measure{ render_without_benchmark(template_name, status) }.real

        if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
          @db_rt_before_render = db_runtime
          @db_rt_after_render = ActiveRecord::Base.connection.reset_runtime
          @rendering_runtime -= @db_rt_after_render
        end
      end
    end    

    def perform_action_with_benchmark
      if logger.nil?
        perform_action_without_benchmark
      else
        runtime = [Benchmark::measure{ perform_action_without_benchmark }.real, 0.0001].max
        log_message  = "Completed in #{sprintf("%.5f", runtime)} (#{(1 / runtime).floor} reqs/sec)"
        log_message << rendering_runtime(runtime) if @rendering_runtime
        log_message << active_record_runtime(runtime) if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
        logger.info(log_message)
      end
    end
    
    private
      def rendering_runtime(runtime)
        " | Rendering: #{sprintf("%.5f", @rendering_runtime)} (#{sprintf("%d", (@rendering_runtime * 100) / runtime)}%)"
      end

      def active_record_runtime(runtime)
        db_runtime    = ActiveRecord::Base.connection.reset_runtime
        db_runtime    += @db_rt_before_render if @db_rt_before_render
        db_runtime    += @db_rt_after_render if @db_rt_after_render
        db_percentage = (db_runtime * 100) / runtime
        " | DB: #{sprintf("%.5f", db_runtime)} (#{sprintf("%d", db_percentage)}%)"
      end
  end
end
