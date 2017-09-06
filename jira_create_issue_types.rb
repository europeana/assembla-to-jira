# frozen_string_literal: true

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' TEST' : '')

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
