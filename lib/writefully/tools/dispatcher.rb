module Writefully
  module Tools
    class Dispatcher
      include Celluloid

      attr_reader :job

      def initialize
        every 1.second do 
          async.heartbeat
        end
      end

      def get_job_data
        Writefully.redis.with { |c| c.blpop 'jobs' }
      end

      def heartbeat
        @job      = Marshal.load(get_job_data)
        run_job if job_valid?
      end

      def run_job
        if    retry_valid?   then retry_job
        elsif job_valid?     then dispatch
        end
      end

      def dispatch
        Celluloid::Actor[job[:worker]].perform(job[:message])
      end

      def retry_job
        Celluloid::Actor[:retryer].retry(job)
      end

      def is_retry?
        job_valid? and job[:message].has_key?(:tries) and job[:message].has_key?(:run)
      end

      def job_valid?
        job.has_key?(:worker) and job.has_key?(:message)
      end

      def retry_valid?
        is_retry? and (job[:message][:run] == false)
      end

    end
  end
end