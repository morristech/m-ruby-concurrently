module Concurrently
  # Not to be instantiated directly. An instance will be returned by
  # {current}, {Concurrently::Proc#call} or one of its variants.
  class Evaluation
    # The evaluation that is currently running.
    #
    # @return [Evaluation]
    #
    # @example
    #   concurrent_proc do
    #     Concurrently::Evaluation.current # => #<Concurrently::Proc::Evaluation:0x00000000e56910>
    #   end.call_nonblock
    #
    #   Concurrently::Evaluation.current # => #<Concurrently::Evaluation0x00000000e5be10>
    def self.current
      EventLoop.current.run_queue.current_evaluation
    end

    # @api private
    def initialize(fiber)
      @fiber = fiber
    end

    # The fiber the evaluation runs inside.
    #
    # @api private
    attr_reader :fiber

    # @overload waiting?
    #
    # Checks if the evaluation is waiting
    #
    # @return [Boolean]
    attr_reader :waiting
    class_eval{ alias waiting? waiting } # remove alias from documentation
    undef waiting

    # @api private
    DEFAULT_RESUME_OPTS = { deferred_only: true }.freeze
    
    # Schedules the evaluation to be resumed
    #
    # It needs to be complemented with an earlier call to {Kernel#await_resume!}.
    #
    # @return [:resumed]
    # @raise [Error] if the evaluation is not waiting
    #
    # @note This method only works in certain circumstances. As a reminder its
    #   name has an exclamation mark it its end.
    #
    # @example
    #   evaluation = concurrent_proc do
    #     await_resume!
    #     :resumed
    #   end.call_nonblock
    #
    #   evaluation.resume!
    #   evaluation.await_result # => :resumed
    def resume!(result = nil)
      raise Error, "evaluation is not waiting due to an earlier call of Kernel#await_resume!" unless @waiting

      run_queue = Concurrently::EventLoop.current.run_queue

      # Cancel running the fiber if it has already been scheduled to run; but
      # only if it was scheduled with a time offset. This is used to cancel the
      # timeout of a wait operation if the waiting fiber is resume before the
      # timeout is triggered.
      run_queue.cancel(self, DEFAULT_RESUME_OPTS)

      run_queue.schedule_immediately(self, result)
      :resumed
    end
  end
end