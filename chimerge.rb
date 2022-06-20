# frozen_string_literal: true

DATA_COL = (0..3).freeze # Specify the data columns
CLASS_COL = 4 # The class information column

# IRIS dataset object, for storage and processing
class IrisData
  attr_reader :data, :class_list, :tables

  def initialize(filename)
    @file = File.open(filename, 'r')
    @class_list = []
    @tables = [] # Store ChiMerged data tables
    parse_data
    warn "Loaded IRIS d ataset with #{data.count} tuples."
  end

  def discretize_by_chi(col_num, **chi_args)
    raise ArgumentError, 'Selected attribute index out of range' unless DATA_COL.include?(col_num)

    table = IntervalTable.new(self, col_num, **chi_args)
    table.chimerge
    tables[col_num] = table
  end

  private

  # Parse data into array
  def parse_data
    @data = []
    @file.each do |line|
      line.strip!
      next if line.empty?

      # The fifth attribute is of type String
      @data << line.split(',').map.with_index do |item, index|
        if index == CLASS_COL
          # Store class names in array
          class_name = item.to_str
          @class_list << class_name unless class_list.include?(class_name)
          class_name
        else
          item.to_f
        end
      end
    end
  end
end

# ChiMerge interval table for merging
class IntervalTable
  attr_accessor :table, :chi, :merged

  # If batch_merge is set to true, all intervals with lowest chi will be merged every round
  def initialize(dataset, ref_col, **chi_args)
    @ref_col = ref_col
    @max_interval = chi_args[:max_interval] || 6
    @chi_threshold = chi_args[:chi_threshold] || 4.61
    @batch_merge = chi_args[:batch_merge] || false
    @expected_freq_threshold = chi_args[:expected_freq_threshold] || 0.5
    @chi_tester = ChiSquare.new(expected_freq_threshold: @expected_freq_threshold)
    sort_data(dataset, ref_col)
    print_table_info(table)
  end

  # Main merge loop
  def chimerge
    print_round_info
    @merged ||= table.dup
    populate_chi
    lowest_chi = chi.min
    # Stop recursion if any stopping criteria are met
    return display_merged if merged.count < @max_interval || lowest_chi > @chi_threshold

    merge_by_chi(lowest_chi)
    print_table_info(merged)
    chimerge
  end

  private

  # Clean and sort tuples into [[interval range], [...class frequencies]]
  # Put data examples with the same value into the same interval range
  def sort_data(dataset, ref_col)
    @table = []
    # Loop through each data tuple
    dataset.data.each do |tuple|
      class_list = dataset.class_list
      class_index = class_list.index(tuple[CLASS_COL])
      ref = tuple[ref_col]
      exists = table.find { |interval| interval[0].include?(ref) }
      if exists
        exists[0] << ref
        exists[1][class_index] += 1
      else
        @table << [[ref], class_list.map.with_index { |_name, index| index == class_index ? 1 : 0 }]
      end
    end
    table.sort!
  end

  # Populate chi after initial data parse
  def populate_chi
    @chi ||= []
    (merged.length - 1).times do |index|
      chi[index] ||= chitest_at(index)
    end
    print_chi
  end

  # After merging, update related chi values
  def update_chi_after_merge(index)
    index.positive? && chi[index - 1] = nil
    (index + 1) < chi.count && chi[index + 1] = nil
    chi.delete_at(index)
  end

  # Calc chi-square value only when merging
  def chitest_at(index)
    @chi_tester.test(merged[index][1], merged[index + 1][1])
  end

  # Merge by the lowest chi-square value,
  # if batch_merge is true, merge recursively until all lowest chi intervals are exhausted
  def merge_by_chi(val)
    index = chi.index(val) # Get the index to merge at
    return if index.nil?

    merging = "#{interval_to_s(index, merged)} and #{interval_to_s(index + 1, merged)}"
    warn "Merging interval #{merging} by chi #{val.round(3)}"
    merge(index)
    merge_by_chi(val) if @batch_merge # Merge recursively if batch_merge is true
  end

  # Merge two interval
  def merge(index)
    this_interval = merged[index]
    next_interval = merged[index + 1]
    merged[index][0] += next_interval[0]
    merged[index][1] = this_interval[1].zip(next_interval[1]).map(&:sum)
    merged.delete_at(index + 1)
    # When merged, update the corresponding chi sequence
    update_chi_after_merge(index)
    raise IndexError unless chi.count == merged.count - 1
  end

  def intervals(data)
    data.length.times.map do |index|
      interval_to_s(index, data)
    end
  end

  # Interval to string
  def interval_to_s(index, data = table)
    "[#{data[index][0].min} (#{data[index][1].join(', ')})]"
  end

  def print_table_info(data)
    warn "Interval count: #{data.count}\n"
    warn "Intervals: #{intervals(data).join(', ')}\n"
  end

  def print_chi
    # Pretty print interval -> chi pairs for inspection
    chi_pairs = merged.length.times.map do |index|
      "#{interval_to_s(index, merged)} -> #{chi[index]&.round(2) || 'nil'}"
    end
    # chi_pairs = intervals(data).zip(rounded_chi).map { |pair| "(#{pair[0]} -> #{pair[1] || 'nil'})" }
    warn "Chi values updated: #{chi_pairs.join(', ')}\n"
  end

  def print_round_info
    @round ||= 0
    round_info = "# ROUND #{@round += 1} #"
    warn "##{'=' * (round_info.length - 2)}#"
    warn round_info
    warn "##{'=' * (round_info.length - 2)}#"
  end

  def print_merged
    merged.each_with_index do |interval, index|
      warn "# [#{interval[0].min}..#{interval[0].max}]: #{interval[1]}, chi: #{chi[index]&.round(2) || 'nil'}\n"
    end
  end

  def print_merge_params
    warn <<~INFO
      ############################################
      # Data column #{@ref_col} discretized with ChiMerge
      # Rounds elapsed: #{@round}
      # Max interval: #{@max_interval}
      # Chi threshold: #{@chi_threshold}
      # Expected frequency threshold: #{@expected_freq_threshold}
      # Batch merged: #{@batch_merge}
      ++++++++++++++++++++++++++++++++++++++++++++
    INFO
  end

  def display_merged
    print_merge_params
    print_merged
    warn "############################################\n"
  end
end

# Chi-square value calcualtor
class ChiSquare
  def initialize(expected_freq_threshold: 0.5)
    @expected_freq_threshold = expected_freq_threshold
  end

  # Pass in an 2-D array, each subarray stands for an target event,
  # and their items the frequency of the co-occuring query event.
  # Return chi-score.
  # Caveat: assume all subarrays are of the same length.
  def test(*target_events)
    chi_score = 0
    target_length = target_events.length # The length of target events (intervals)
    query_length = target_events.first.length # The length of query events (classes)
    target_sum = target_events.map(&:sum) # Calculate the sum of each target event
    query_sum = target_events.transpose.map(&:sum) # Calculate the sum of each query event
    total_freq = target_sum.sum # The total frequency (N)
    # Loop through target events, then query events, and calculate the chi-score
    (0..(target_length - 1)).each do |target_index|
      (0..(query_length - 1)).each do |query_index|
        expected_freq = (target_sum[target_index] * query_sum[query_index]) / total_freq.to_f
        next if expected_freq.zero?

        # Use a given threshold (e.g. 0.5) to if the expected frequency is too small
        expected_freq = @expected_freq_threshold if expected_freq < @expected_freq_threshold
        # Calculate and return the chi-score for the specific event combination
        score = (target_events[target_index][query_index] - expected_freq)**2 / expected_freq
        chi_score += score
      end
    end
    chi_score
  end
end

iris = IrisData.new('iris.data')
iris.discretize_by_chi(3, max_interval: 5, chi_threshold: 4.61, expected_freq_threshold: 0.5, batch_merge: true)
