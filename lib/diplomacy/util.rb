module Diplomacy
  module Util
    # Assuming the keys are strings, return the value for whichever
    # key matches the potentially partial key given.
    def self.partial_match(array, key)
      candidates = (0...array.size).to_a
      pos = 0
      #		Util.log "Matching '#{key}'..."
      while candidates.size > 1 and pos < key.size
        candidates.delete_if do |c|
          str = nil
          if block_given?
            str = (yield array[c]).to_s
          else
            str = array[c].to_s
          end
          str[pos,1] != key[pos,1]
        end
        pos += 1
      end
      if candidates.size == 0
        return nil
      elsif candidates.size == 1
        return array[candidates.first]
      else
        raise ArgumentError, "String #{key.inspect} insufficient to determine which element in array to select. Options are: #{candidates.map!{|c| array[c].to_s}.join(', ')}"
      end
    end

    def self.log(*args)
      $log ||= File.open("log", "w")
      $log.puts(*args) # if $DEBUG or $0.index("test")
    end

    def self.ailog(*args)
      $ailog ||= File.open("ailog", "w")
      $ailog.puts(*args)
    end
  end
end
