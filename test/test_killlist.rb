$:.unshift './lib'
require 'bitchannel/killlist'
require 'test/unit'

class TestBitChannelKillList < Test::Unit::TestCase

  def test_s_parse
    list = BitChannel::KillList.parse('')
    assert_instance_of BitChannel::KillList, list

    assert_raise(BitChannel::KillListParseError) {
      BitChannel::KillList.parse('a a a')
    }
  end

  def test_AREF
    list = BitChannel::KillList.parse('a 2')
    assert_instance_of BitChannel::IntList, list['a']
    assert_instance_of BitChannel::IntList, list['notexist']
  end

  def test_include?
    list = BitChannel::KillList.parse('
      a 2
      b 3,4,5
      c 6-8
      d 9,10,12-14
    ')
    assert_equal false, list['a'].include?(0)
    assert_equal false, list['a'].include?(1)
    assert_equal true, list['a'].include?(2)
    assert_equal false, list['a'].include?(3)
    assert_equal false, list['a'].include?(100)

    assert_equal false, list['b'].include?(0)
    assert_equal false, list['b'].include?(2)
    assert_equal true, list['b'].include?(3)
    assert_equal true, list['b'].include?(4)
    assert_equal true, list['b'].include?(5)
    assert_equal false, list['b'].include?(6)
    assert_equal false, list['b'].include?(100)

    assert_equal false, list['c'].include?(0)
    assert_equal false, list['c'].include?(5)
    assert_equal true, list['c'].include?(6)
    assert_equal true, list['c'].include?(7)
    assert_equal true, list['c'].include?(8)
    assert_equal false, list['c'].include?(9)
    assert_equal false, list['c'].include?(100)

    assert_equal false, list['d'].include?(0)
    assert_equal false, list['d'].include?(8)
    assert_equal true, list['d'].include?(9)
    assert_equal true, list['d'].include?(10)
    assert_equal false, list['d'].include?(11)
    assert_equal true, list['d'].include?(12)
    assert_equal true, list['d'].include?(13)
    assert_equal true, list['d'].include?(14)
    assert_equal false, list['d'].include?(15)
    assert_equal false, list['d'].include?(16)
    assert_equal false, list['d'].include?(100)
  end

  def test_overlap?
    list = BitChannel::KillList.parse('
      a 2
      b 3,4,5
      c 6-8
      d 9,10,13-14
    ')
    assert_equal false, list['a'].overlap?(0..1)
    assert_equal true, list['a'].overlap?(0..2)
    assert_equal true, list['a'].overlap?(2..4)
    assert_equal true, list['a'].overlap?(0..4)
    assert_equal false, list['a'].overlap?(3..5)

    assert_equal false, list['b'].overlap?(0..2)
    assert_equal true, list['b'].overlap?(0..3)
    assert_equal true, list['b'].overlap?(0..4)
    assert_equal true, list['b'].overlap?(0..5)
    assert_equal true, list['b'].overlap?(0..6)
    assert_equal true, list['b'].overlap?(3..6)
    assert_equal true, list['b'].overlap?(4..6)
    assert_equal true, list['b'].overlap?(5..6)
    assert_equal false, list['b'].overlap?(6..8)

    assert_equal false, list['c'].overlap?(0..5)
    assert_equal true, list['c'].overlap?(0..6)
    assert_equal true, list['c'].overlap?(0..7)
    assert_equal true, list['c'].overlap?(0..8)
    assert_equal true, list['c'].overlap?(6..8)
    assert_equal true, list['c'].overlap?(7..8)
    assert_equal true, list['c'].overlap?(6..12)
    assert_equal true, list['c'].overlap?(7..12)
    assert_equal true, list['c'].overlap?(8..12)
    assert_equal false, list['c'].overlap?(9..12)

    assert_equal false, list['d'].overlap?(0..7)
    assert_equal false, list['d'].overlap?(0..8)
    assert_equal true, list['d'].overlap?(0..9)
    assert_equal true, list['d'].overlap?(0..11)
    assert_equal true, list['d'].overlap?(0..12)
    assert_equal true, list['d'].overlap?(0..13)
    assert_equal true, list['d'].overlap?(0..14)
    assert_equal true, list['d'].overlap?(0..15)
    assert_equal true, list['d'].overlap?(0..15)
    assert_equal true, list['d'].overlap?(9..100)
    assert_equal true, list['d'].overlap?(10..100)
    assert_equal true, list['d'].overlap?(11..100)
    assert_equal false, list['d'].overlap?(11..12)
    assert_equal true, list['d'].overlap?(10..12)
    assert_equal true, list['d'].overlap?(11..13)
    assert_equal true, list['d'].overlap?(11..16)
    assert_equal false, list['d'].overlap?(15..100)
    assert_equal false, list['d'].overlap?(16..100)
  end

end
