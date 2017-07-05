class Stage
  class Benchmark
    SECONDS = 1
    RESULT_HEADER = "Results for #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}"
    RESULT_FORMAT = "  %-25s %8d executions in %2.4f seconds"

    def self.header
      <<DOC
Benchmarks
----------
DOC
    end

    def self.result_header
      "#{RESULT_HEADER}\n#{'-'*RESULT_HEADER.length}"
    end

    def initialize(stage, name, opts = {})
      @stage = stage
      @name = name
      @opts = opts

      proc = opts[:proc]
      call = opts[:call] || :call_nonblock
      args = opts[:args]
      sync = opts[:sync]
      batch_size = opts[:batch_size] || 1

      code_gen = if batch_size > 1
        CodeGen::Batch.new(proc, call, args, sync, batch_size)
      else
        CodeGen::Single.new(proc, call, args, sync)
      end

      proc_lines = code_gen.proc_lines
      args_lines = code_gen.args_lines
      call_lines = code_gen.call_lines
      @code = eval [*proc_lines, *args_lines, "", *call_lines].join "\n"

      call_lines[0] = "while elapsed_seconds < #{SECONDS}"
      @desc = ["  #{@name}:", *proc_lines, *args_lines, "", *call_lines, ""].join "\n    "
    end

    attr_reader :desc

    def run
      result = @stage.gc_disabled do
        @stage.execute(seconds: SECONDS, &@code)
      end
      puts sprintf(RESULT_FORMAT, "#{@name}:", @opts[:batch_size]*result[:iterations], result[:time])
    end
  end
end