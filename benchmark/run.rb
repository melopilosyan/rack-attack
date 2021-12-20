gem 'redis', '~> 4.0'
gem 'dalli', '~> 3.0'
gem 'activesupport', '~> 6.1.0'

require 'benchmark/ips'

require 'active_support'

require_relative 'lib/redis_adapter'
require_relative 'lib/active_support_redis_store_proxy'

require_relative 'lib/dalli_client_adapter'
require_relative 'lib/mem_cache_store_proxy'


### Redis
as_cache_store = ActiveSupport::Cache::RedisCacheStore.new
### Redis wrapped in ConnectionPool
# as_cache_store = ActiveSupport::Cache::RedisCacheStore.new pool_size: 3
### Redis::Distributed
# as_cache_store = ActiveSupport::Cache::RedisCacheStore.new url: ['redis://localhost:6379/0', 'redis://localhost:6379/2', 'redis://localhost:6379/3']


proxy = Rack::Attack::StoreProxy::ActiveSupportRedisStoreProxy.new as_cache_store
adapter = Rack::Attack::Adapters::RedisAdapter.build as_cache_store.redis


as_mem_cache = ActiveSupport::Cache::MemCacheStore.new

mem_proxy = Rack::Attack::StoreProxy::MemCacheStoreProxy.new as_mem_cache
mem_adapter = Rack::Attack::Adapters::DalliClientAdapter.build as_mem_cache.instance_variable_get(:@data)


PERIOD = 3


def benchmark(proxy, adapter)
  Benchmark.ips do |x|
    x.config(time: 10)

    x.report('proxy') { proxy.increment 'proxy/key', 1, expires_in: PERIOD }
    x.report('adapter') { adapter.increment 'adapter/key', 1, expires_in: PERIOD }

    x.compare!
  end
end

def benchmark_full(proxy, adapter)
  Benchmark.ips do |x|
    x.config(time: 10)

    x.report('proxy') do
      now = Time.now.to_i

      key = "proxy/#{now / PERIOD}/key"
      expires_in = PERIOD - (now % PERIOD) + 1

      proxy.increment key, 1, expires_in: expires_in
    end

    x.report('adapter') do
      key = "adapter/#{PERIOD}/key"
      adapter.increment key, 1, expires_in: PERIOD
    end

    x.compare!
  end
end

def benchmark_redis_vs_memcached(mem_adapter, redis_adapter)
  Benchmark.ips do |x|
    x.config(time: 10)

    x.report('memcached') do
      key = "memcached/#{PERIOD}/key"
      mem_adapter.increment key, 1, expires_in: PERIOD
    end

    x.report('redis') do
      key = "redis/#{PERIOD}/key"
      redis_adapter.increment key, 1, expires_in: PERIOD
    end

    x.compare!
  end
end

# benchmark(proxy, adapter)
benchmark_full(proxy, adapter)
# benchmark_redis_vs_memcached(mem_adapter, adapter)
