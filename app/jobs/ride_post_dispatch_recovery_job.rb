class RidePostDispatchRecoveryJob < ApplicationJob
  queue_as :default

  def perform
    RidePostDispatch.find_each(&:enqueue)
  end
end
