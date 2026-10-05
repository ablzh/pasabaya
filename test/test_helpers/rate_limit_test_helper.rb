module RateLimitTestHelper
  def with_rate_limit_cache
    store = ActiveSupport::Cache::MemoryStore.new
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = store

    # Production uses shared cache counters. Keep real counters isolated per test
    # without enabling unrelated caching in the test environment.
    with_stubbed_method(ActionController::Base.cache_store, :increment,
      ->(key, amount, options) { store.increment(key, amount, **options) }) do
      yield store
    end
  ensure
    Rack::Attack.cache.store = original_store
  end
end
