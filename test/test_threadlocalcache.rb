require 'test/unit'
$LOAD_PATH.unshift './lib'
require 'bitchannel/threadlocalcache'

class Test_BitChannel_ThreadLocalCache < Test::Unit::TestCase

  class A
    include BitChannel::ThreadLocalCache
    def object
      update_tlc_slot('bitchannel.test.object') { "OK" }
    end
  end

  def test_AREF
    n_threads = 20
    n = 50

    threads = []
    n_threads.times do
      threads.push Thread.fork {
        a1 = A.new
        a2 = A.new
        obj = nil
        n.times do
          assert_same obj, a1.object if obj
          obj = a1.object
          assert_same obj, a2.object
          Thread.pass
        end
      }
    end
    threads.each do |th|
      th.join
    end
  end

end
