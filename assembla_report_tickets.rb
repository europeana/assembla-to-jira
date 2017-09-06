# frozen_string_literal: true

#
# Generates a summary report for tickets listed in order of most comments, tags, associations and attachments
# by analyzing all of the assembla dump csv files.
#
# count | ticket_id | ticket_number | tags | comments | attachments | associations

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

tickets_csv = "#{dirname_assembla}/tickets.csv"
report_tickets_csv = "#{dirname_assembla}/report-tickets.csv"

@tickets = csv_to_array(tickets_csv)
@report_tickets = []

@ticket_id_seen = {}
@ticket_nr_seen = {}

@ticket_id_dups = []
@ticket_nr_dups = []

# Sanity check just in case
@tickets.each_with_index do |ticket, index|
  id = ticket['id']
  nr = ticket['number']
  @report_tickets << {
    count: 0,
    id: id,
    number: nr,
    tags: 0,
    comments: 0,
    attachments: 0,
    associations: 0
  }
  if id.nil? || nr.nil? || !(id.match(/^\d+$/) && nr.match(/^\d+$/))
    puts "Invalid line #{index + 1}: ticket=#{ticket.inspect}"
    next
  end
  if @ticket_id_seen[id]
    @ticket_id_dups << id if @ticket_id_seen[id] == 1
    @ticket_id_seen[id] += 1
  else
    @ticket_id_seen[id] = 1
  end
  if @ticket_nr_seen[nr]
    @ticket_nr_dups << nr if @ticket_nr_seen[nr] == 1
    @ticket_nr_seen[nr] += 1
  else
    @ticket_nr_seen[nr] = 1
  end
end

goodbye("Duplicate ticket ids: #{@ticket_id_dups.join(',')}") if @ticket_id_dups.length.positive?
goodbye("Duplicate ticket nrs: #{@ticket_nr_dups.join(',')}") if @ticket_nr_dups.length.positive?

%w(tags comments attachments associations).each do |file|
  file_csv = "#{dirname_assembla}/ticket-#{file}.csv"
  records = csv_to_array(file_csv)
  records.each do |record|
    ticket_id = record['ticket_id']
    report_ticket = @report_tickets.find{ |report_ticket| report_ticket[:id] == ticket_id }
    if report_ticket
      report_ticket[:count] += 1
      report_ticket[file.to_sym] += 1
    else
      goodbye("Cannot find ticket_id='#{ticket_id}' for #{file}")
    end
  end
end

@report_tickets.sort!{|x,y| y[:count] <=> x[:count]}

write_csv_file(report_tickets_csv, @report_tickets)

