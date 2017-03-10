require_relative '../lib/diplomacy/signals'
require 'test/unit'

class A
  include SignalSource
  def x=(value)
    emit(:x=, value)
  end
end

class B
  attr_reader :a, :updated
  def initialize
    @updated = false
    @a = A.new
    @a.connect(:x=, self, :update)
  end

  def update(x)
    @updated = true
  end
end

class SignalsTest < Test::Unit::TestCase
  def test_emit
    b = B.new
    b.a.x = 10
    assert b.updated
  end
end
