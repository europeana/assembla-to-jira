# frozen_string_literal: true

#
# Generates a summary report for tickets listed in order of most comments, tags, associations and attachments
# by analyzing all of the assembla dump csv files.
#
# count | ticket_id | ticket_number | tags | comments | attachments | associations

load './lib/common.rb'

space = get_space(ASSEMBLA_SPACE)
dirname_assembla = get_output_dirname(space, 'assembla')

tickets_csv = "#{dirname_assembla}/tickets.csv"
report_tickets_csv = "#{dirname_assembla}/report-tickets.csv"

@tickets = csv_to_array(tickets_csv)
@report_tickets = []

# Sanity check just in case
@tickets.each do |ticket|
  @report_tickets << {
    count: 0,
    id: ticket['id'],
    number: ticket['number'],
    tags: 0,
    comments: 0,
    attachments: 0,
    associations: 0
  }
end

%w(tags comments attachments associations).each do |file|
  file_csv = "#{dirname_assembla}/ticket-#{file}.csv"
  records = csv_to_array(file_csv)
  records.each do |record|
    ticket_id = record['ticket_id']
    report_ticket = @report_tickets.detect { |t| t[:id] == ticket_id }
    if report_ticket
      report_ticket[:count] += 1
      report_ticket[file.to_sym] += 1
    else
      goodbye("Cannot find ticket_id='#{ticket_id}' for #{file}")
    end
  end
end

@report_tickets.sort! { |x, y| y[:count] <=> x[:count] }

write_csv_file(report_tickets_csv, @report_tickets)
