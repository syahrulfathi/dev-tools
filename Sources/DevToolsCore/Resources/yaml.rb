require 'psych'

begin
  input = STDIN.read.force_encoding('UTF-8')
  # Parse syntax trees only: never instantiate Ruby objects or resolve aliases.
  stream = Psych.parse_stream(input)
  normalize = lambda do |node|
    if node.is_a?(Psych::Nodes::Mapping) || node.is_a?(Psych::Nodes::Sequence)
      node.style = Psych::Nodes::Mapping::BLOCK
    end
    (node.children || []).each { |child| normalize.call(child) }
  end
  normalize.call(stream)
  STDOUT.write(stream.yaml(nil, :indentation => 2, :line_width => -1))
rescue Psych::Exception => error
  STDERR.write(error.message)
  exit 1
end
