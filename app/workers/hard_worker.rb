class HardWorker
  include Sidekiq::Worker

  def perform
    Animal.create(description: 'blob')
  end
end