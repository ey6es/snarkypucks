if Delayed::Job.table_exists? && Delayed::Job.where("handler like '%PromptsGenerateJob%'").count == 0
  PromptsGenerateJob.perform_later
end

