#!/usr/bin/env ruby
require_relative '../lib/typed_array'

# Base   - base_class
# Dire   - direct_class
# BD     - base_class direct_class
# Limit  - size
# Strict - index_strict
# ISL    - size index_strict

class TypedBaseArray < TypedArray; end
class TypedDireArray < TypedArray; end
class TypedBDArray < TypedArray; end
class TypedMTArray < TypedArray; end
class TypedBaseLimitArray < TypedArray; end
class TypedDireLimitArray < TypedArray; end
class TypedBDLimitArray < TypedArray; end
class TypedBaseStrictArray < TypedArray; end
class TypedDireStrictArray < TypedArray; end
class TypedBDStrictArray < TypedArray; end
class TypedBaseILSArray < TypedArray; end
class TypedDireILSArray < TypedArray; end
class TypedBDILSArray < TypedArray; end

require 'minitest/autorun'
require 'minitest/spec'

EMPTY_OBJECT = Object.new
EMPTY_INTEGER = [1,2,3,4,5]
EMPTY_CHAR = ['a','b','c']

describe TypedArray do
  before do
    
  end
  
  describe "simple typed array" do
    it "have basic base class" do
      TypedBaseArray.instance_exec do
        build base_class: [Integer]
        new.tap do |ta|
          ta.must_be :empty?
          ta.must_be_kind_of TypedArray
          ta.must_be_instance_of self
          rand(200..500).tap do |sz|
            1.upto sz do |s| ta.push sz % s end
            ta.size.must_be :==, sz
          end
          proc do
            ta.push 'a'
          end.must_raise TypeError
        end
        new(*EMPTY_INTEGER).tap do |ta|
          ta.wont_be :empty?
          ta.size.must_be :>, 0
          ta.must_be_kind_of TypedArray
          ta.must_be_instance_of self
        end
        proc do
          new(*EMPTY_CHAR)
        end.must_raise TypeError
      end
    end
    
    it "have basic direct class" do
      TypedDireArray.instance_exec do
        build direct_class: [Fixnum]
        new.tap do |ta|
          ta.must_be :empty?
          ta.must_be_kind_of TypedArray
          ta.must_be_instance_of self
          rand(200..500).tap do |sz|
            1.upto sz do |s| ta.push sz % s end
            ta.size.must_be :==, sz
          end
          proc do
            ta.push 'a'
          end.must_raise TypeError
        end
        new(*EMPTY_INTEGER).tap do |ta|
          ta.wont_be :empty?
          ta.size.must_be :>, 0
          ta.must_be_kind_of TypedArray
          ta.must_be_instance_of self
        end
        proc do new(*EMPTY_CHAR) end.must_raise TypeError
        proc do new(2 << 80, 2 << 81) end.must_raise TypeError
      end
    end
    
    it "have basic base-direct class" do
      TypedBDArray.instance_exec do
        build base_class: [Integer], direct_class: [Object]
        new.tap do |ta|
          ta.must_be :empty?
          ta.must_be_kind_of TypedArray
          ta.must_be_instance_of self
          rand(200..500).tap do |sz|
            1.upto sz do |s| ta.push sz % s end
            ta.size.must_be :==, sz
          end
          proc do
            ta.push 'a'
          end.must_raise TypeError
        end
        new(*EMPTY_INTEGER).tap do |ta|
          ta.wont_be :empty?
          ta.size.must_be :>, 0
          ta.must_be_kind_of TypedArray
          ta.must_be_instance_of self
        end
        new(EMPTY_OBJECT).tap do |ta|
          ta.wont_be :empty?
          ta.must_be_kind_of TypedBDArray
          ta.must_be_instance_of self
        end
        proc do new *EMPTY_CHAR end.must_raise TypeError
      end
    end
    
    it "cannot have total untyped class" do
      proc do
        TypedMTArray.send :build
      end.must_raise ArgumentError
    end
  end
  
  describe "typed array with limits" do
    it "have base class with upper limit" do
      TypedBaseLimitArray.send :build, base_class: [Integer], size: 0..10
      TypedBaseLimitArray.new.must_be :empty?
      TypedBaseLimitArray.new(*(EMPTY_INTEGER)).must_be_kind_of TypedBaseLimitArray
      proc do
        TypedBaseLimitArray.new *(EMPTY_INTEGER * 3)
      end.must_raise RangeError
    end
    
    it "have direct class with lower limit" do
      TypedDireLimitArray.send :build, direct_class: [String], size: 2..Float::INFINITY
      proc do
        TypedDireLimitArray.new
      end.must_raise RangeError
      TypedDireLimitArray.new(*EMPTY_CHAR).must_be_kind_of TypedDireLimitArray
      TypedDireLimitArray.new(*(EMPTY_CHAR * 1000)).must_be_kind_of TypedDireLimitArray
    end
    
    it "have base-direct class with bounded limit" do
      TypedBDLimitArray.send :build, base_class: [Integer], direct_class: [Object], size: 3..5
      proc do
        TypedBDLimitArray.new
      end.must_raise RangeError
      TypedBDLimitArray.new(*EMPTY_INTEGER).must_be_kind_of TypedBDLimitArray
      proc do
        TypedBDLimitArray.new *([EMPTY_OBJECT]*5 + EMPTY_INTEGER)
      end.must_raise RangeError
    end
  end
  
  describe "typed array with indexed checks" do
    it "have rotating base class checks" do
      TypedBaseStrictArray.send :build, base_class: ([Integer] * 5 + [String] * 3), index_strict: true
      TypedBaseStrictArray.new
      proc do
        TypedBaseStrictArray.new *EMPTY_CHAR
      end.must_raise TypeError
      TypedBaseStrictArray.new *(EMPTY_INTEGER + EMPTY_CHAR)
    end
    
    it "have rotating direct class checks" do
      TypedDireStrictArray.send :build, direct_class: [Fixnum,String,Fixnum,Array], index_strict: true
      TypedDireStrictArray.new
      proc do
        TypedDireStrictArray.new *EMPTY_INTEGER
      end.must_raise TypeError
      proc do
        TypedDireStrictArray.new *EMPTY_CHAR
      end.must_raise TypeError
      proc do
        TypedDireStrictArray.new EMPTY_OBJECT
      end.must_raise TypeError
      TypedDireStrictArray.new 1,'2',3,[4],5,'6',7,[8]
      TypedDireStrictArray.new 1
      proc do
        TypedDireStrictArray.new (2<<80)
      end.must_raise TypeError
    end
    
    it "have rotating base-direct class checks" do
      TypedBDStrictArray.send :build, base_class: [Integer, String], direct_class: [Array, IO], index_strict: true
      TypedBDStrictArray.new.must_be_kind_of TypedBDStrictArray
      TypedBDStrictArray.new(1).must_be_kind_of TypedArray
      proc do
        TypedBDStrictArray.new '2'
      end.must_raise TypeError
      TypedBDStrictArray.new([3]).must_be_kind_of TypedBDStrictArray
      proc do
        TypedBDStrictArray.new $stdout
      end.must_raise TypeError
      TypedBDStrictArray.new(1, $stdout).must_be_kind_of TypedArray
      TypedBDStrictArray.new([2], '3').must_be_kind_of TypedArray
    end
  end
  
  describe "typed array with indexed checks and size bounded" do
    it "have rotating base class with bounded size" do
      TypedBaseILSArray.send :build, base_class: [Fixnum,Bignum,Float,Numeric], index_strict: true, size: 3..9
      TypedBaseILSArray.new(1,2<<80,3.0).tap do |tbils|
        tbils.must_be_kind_of TypedArray
        tbils.must_be_kind_of TypedBaseILSArray
      end
    end
  end
end
