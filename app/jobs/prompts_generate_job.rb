class PromptsGenerateJob < ActiveJob::Base
  queue_as :default

  def perform(*args)
    begin
      Prompt.fill_pools
      Prompt.where(game_id: nil).where(["expires <= ?", DateTime.now]).destroy_all
    ensure
      if Delayed::Job.where("handler like '%PromptsGenerateJob%'").count == 1
        PromptsGenerateJob.set(wait: 30.minute).perform_later
      end
    end
  end
end
