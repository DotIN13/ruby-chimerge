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

# first_event = [5, 0, 5]
# second_event = [5, 5, 5]
third_event = [5, 2, 10]

tester = ChiSquare.new(expected_freq_threshold: 0.0)

# first_pair = tester.test(first_event, second_event)
# warn first_pair

(0..99).to_a.repeated_permutation(3).each do |permutation|
  second_pair = tester.test(third_event, permutation)
  deviation = (second_pair - 2.0).abs
  print "#{permutation.join(', ')}, #{second_pair}, #{deviation}\n" if deviation < 10e-10
end

print "< 2.0\n"

(0..99).to_a.repeated_permutation(3).each do |permutation|
  second_pair = tester.test(third_event, permutation)
  deviation = (second_pair - 2.0)
  print "#{permutation.join(', ')}, #{second_pair}, #{deviation}\n" if deviation.negative?
end
