# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

# --- ASSEMBLA Tickets --- #

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

@issue_types = []
@tickets_assembla.each do |ticket|
  m = /^(.*?):/.match(ticket['summary'])
  if m
    issue_type = m[1]
    unless @issue_types.include?(issue_type)
      @issue_types << issue_type
    end
  end
end

puts "Found the following issue types in summary:"
@issue_types.sort.each do |issue_type|
  puts issue_type
end
