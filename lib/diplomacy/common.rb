# TODO: Replace all this monkey patching!

# Add some methods for our own nefarious purposes.
class Array
  # --- Queries ----------------------------

  def average
    sum / size
  end

  def sum
    result = 0.0
    each { |val| result += val}
    return result
  end

  # A random element.
  def random
    self[rand(size)]
  end

  def maxes(&block)
    result = []
    max_value = map(&block).max
    each do |element|
      result << element if yield(element) == max_value
    end
    return result
  end

  # Assuming the keys are strings, return the value for whichever
  # key matches the potentially partial key given.
  def partial_match(key)
    candidates = (0...size).to_a
    pos = 0
    #		log "Matching '#{key}'..."
    while candidates.size > 1 and pos < key.size
      candidates.delete_if do |c|
        str = nil
        if block_given?
          str = (yield self[c]).to_s
        else
          str = self[c].to_s
        end
        str[pos,1] != key[pos,1]
      end
      #			log "Matches = " + candidates.map{|c| self[c]}.join(', ')
      pos += 1
    end
    if candidates.size == 0
      return nil
    elsif candidates.size == 1
      return self[candidates.first]
    else
      raise ArgumentError, "String #{key.inspect} insufficient to determine which element in array to select. Options are: #{candidates.map!{|c| self[c].to_s}.join(', ')}"
    end
  end

  # The Java-inspired "has" method. Nice because it's shorter.
  alias :has :include?
end

class Hash
  def fetch_default(key, default)
    self[key] = default if self[key].nil?
    return self[key]
  end
end

# Add some methods for our own nefarious purposes.
class Object
  # --- Queries ----------------------------

  # Recursively copy an object and all its attributes into the
  # return value. Raises exception if object contains
  def deep_copy
    Marshal.load(Marshal.dump(self))
  end
end

$log = File.open("log", "w")
def log(*args)
  $log.puts(*args) # if $DEBUG or $0.index("test")
end

$ailog = File.open("ailog", "w")
def ailog(*args)
  $ailog.puts(*args)
end
