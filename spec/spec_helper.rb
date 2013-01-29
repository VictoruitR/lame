require 'lame'
require 'pry'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

def pointer_from_string(str)
  ::FFI::MemoryPointer.from_string(str)
end

module SetterGetter
  def has_getter?(lame, flag)
    lame.respond_to?(:"lame_get_#{flag}")
  end

  def has_setter?(lame, flag)
    lame.respond_to?(:"lame_set_#{flag}")
  end

  def set_value(lame, flag)
    lame.send(:"lame_set_#{flag}", @flags_pointer, @value) == return_value
  end

  def return_value
    defined?(@return) ? @return : 0
  end

  def has_value?(lame, flag)
    if @value && @value.is_a?(Float)
      actual = actual_value(lame, flag)
      (actual - @value).abs < 0.0001
    elsif @value
      actual_value(lame, flag) == @value
    else
      true
    end
  end

  def actual_value(lame, flag)
    lame.send(:"lame_get_#{flag}", @flags_pointer)
  end
end

# Validate existence of a getter, setter and the default value.
RSpec::Matchers.define :have_flag do |expected|
  include SetterGetter

  chain :for do |flags_pointer|
    @flags_pointer = flags_pointer
  end

  chain :with_value do |value|
    @value = value
  end

  match do |actual|
    has_getter?(actual, expected) &&
      has_setter?(actual, expected) &&
      has_value?(actual, expected)
  end
end

# Validate setting a value.
RSpec::Matchers.define :be_able_to_set do |expected|
  include SetterGetter

  chain :for do |flags_pointer|
    @flags_pointer = flags_pointer
  end

  chain :to do |value|
    @value = value
  end

  chain :and_return do |value|
    @return = value
  end

  match do |actual|
    set_value(actual, expected) &&
      has_value?(actual, expected)
  end
end

# Validate getting a value.
RSpec::Matchers.define :have_getter do |expected|
  include SetterGetter

  chain :for do |flags_pointer|
    @flags_pointer = flags_pointer
  end

  chain :with_value do |value|
    @value = value
  end

  match do |actual|
    has_getter?(actual, expected) &&
      has_value?(actual, expected)
  end

  failure_message_for_should do |actual|
    if !has_getter?(actual, expected)
      "expected that #{actual} would have a getter for field :#{expected}"
    elsif @value && !has_value?(actual, expected)
      actual_value = actual_value(actual, expected)
      "expected field :#{expected} to have a value of #{@value}, but got #{actual_value}"
    end
  end
end

# Validate delegation to global_flags.
RSpec::Matchers.define :delegate do |from|

  chain :to do |target|
    @target = target
  end

  match do |subject|
    @from = from
    delegates_setter? &&
      delegates_getter?
  end

  def delegates_setter?
    LAME.should_receive(:"lame_set_#{target}").with(subject.global_flags, anything)
    subject.send(:"#{from}=", double)
    true
  rescue => e
    # TODO: save raised exception for better failure message
    false
  end

  def delegates_getter?
    LAME.should_receive(:"lame_get_#{target}").with(subject.global_flags)
    subject.send(:"#{from}")
    true
  rescue => e
    # TODO: save raised exception for better failure message
    false
  end

  failure_message_for_should do |actual|
    "expected #{subject.class} to delegate :#{from} to LAME.lame_set_#{target}"
  end

  def target
    @target || from
  end

  def from
    @from
  end

end
