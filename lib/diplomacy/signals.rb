module SignalSource

	# Connect a target object to this signal source, so that when it
	# emits the given signal, the given method will be called.
	def connect(signal, target, method)
		init(signal)
#		unless target.respond_to? method
#			raise NoMethodError, "Target needs to respond to method '#{method}'"
#		end
		if signal.nil?
			raise RuntimeException, "Signal 'nil' is not permitted" 
		end
		@_slots[signal].push([target, method])
	end

	# Dettach specific target, or all targets if none specified.
	def disconnect(target=nil, signal=nil)
		if defined? @_slots
			if target
				if signal
					init(signal)
					if @_slots[signal].delete_if{|t,m| t == target }.empty?
						@_slots.delete(signal)
					end
				else
					@_slots.keys.each do |signal|
						dettach(target, signal)
					end
				end
			else
				@_slots.clear
			end
		end
	end

	# The number of targets.
	def count_targets
		if defined? @_slots
			count = 0
			@_slots.values.each{|targets| count += targets.size }
			count
		else
			0
		end
	end

	# The number of signals to which targets are attached.
	def count_signals
		if defined? @_slots
			@_slots.size
		else
			0
		end
	end

	# Call method on all targets
	def emit(signal, *args)
		if defined? @_slots
			init(signal)
			@_slots[signal].each do |target, method|
				begin
					target.send(method, *args)
				rescue ArgumentError => e
					puts "#{target.class}##{method}: #{e.message}"
					raise e
				end
			end
		end
	end

	private
	def init(signal)
		@_slots = {} unless defined? @_slots
		@_slots[signal] = [] if @_slots[signal].nil?
	end
end

