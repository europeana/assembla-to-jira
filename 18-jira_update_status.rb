# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla tickets
tickets_csv = "#{dirname_assembla}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
end

# Only want tickets with state = 0 (closed)
@closed_tickets_assembla = @tickets_assembla.select { |ticket| ticket['state'].to_i.zero? }
@open_tickets_assembla = @tickets_assembla.reject { |ticket| ticket['state'].to_i.zero? }
@done_tickets_assembla = @closed_tickets_assembla.select { |ticket| ticket['status'].casecmp('done').zero? }
@invalid_tickets_assembla = @closed_tickets_assembla.select { |ticket| ticket['status'].casecmp('invalid').zero? }

@total_tickets = @tickets_assembla.length
@total_open_tickets = @open_tickets_assembla.length
@total_closed_tickets = @closed_tickets_assembla.length
@total_done_tickets = @done_tickets_assembla.length
@total_invalid_tickets = @invalid_tickets_assembla.length

puts "Total tickets: #{@total_tickets}, open=#{@total_open_tickets}, closed=#{@total_closed_tickets}, done=#{@total_done_tickets}, invalid=#{@total_invalid_tickets}"

# Some sanity checks just in case.
goodbye('Sanity checks => NOK, total tickets != open + closed') unless @total_tickets == @total_open_tickets + @total_closed_tickets
goodbye('Sanity checks => NOK, total closed tickets != done + invalid') unless @total_closed_tickets == @total_done_tickets + @total_invalid_tickets
puts 'Sanity checks => OK'

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

# Convert assembla_ticket_id to jira_ticket
@assembla_id_to_jira = {}
@tickets_jira.each do |ticket|
  jira_id = ticket['jira_ticket_id']
  assembla_id = ticket['assembla_ticket_id']
  @assembla_id_to_jira[assembla_id] = jira_id
end

# def jira_get_transitions(issue_id)
#   result = nil
#   url = "#{URL_JIRA_ISSUES}/#{issue_id}/translations"
#   begin
#     response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS)
#     result = JSON.parse(response.body)
#     puts "GET #{url} => OK"
#   rescue RestClient::ExceptionWithResponse => e
#     rest_client_exception(e, 'GET', url)
#   rescue => e
#     puts "GET #{url} => NOK (#{e.message})"
#   end
#   result
# end

# POST /rest/api/2/issue/{issueIdOrKey}/transitions
def jira_update_status(issue_id, state, status, counter)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/transitions"
  response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS)
  result = JSON.parse(response)
  transitions = result['transitions']
  done = transitions.find { |transition| transition['name'].casecmp('done').zero?}
  payload = {
    update: {},
    # fields: {
    #   resolution: {
    #     name: status.casecmp('invalid').zero? ? "Won't do" : 'Fixed'
    #   }
    # },
    transition: {
      id: "#{done['id'].to_s}"
    }
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    result = JSON.parse(response.body)
    percentage = ((counter * 100) / @tickets_total).round.to_s.rjust(3)
    puts "#{percentage}% [#{counter}|#{@tickets_total} POST #{url} => OK"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@tickets_total} POST #{url} => NOK (#{e.message})"
  end
  result
end

# jira_get_transitions(@assembla_id_to_jira[@closed_tickets_assembla.first['id']])

@jira_closed_tickets = []

@closed_tickets_assembla.each_with_index do |ticket, index|
  assembla_ticket_id = ticket['id']
  assembla_ticket_state = ticket['state']
  assembla_ticket_status = ticket['status']
  jira_ticket_id = @assembla_id_to_jira[ticket['id']]
  result = jira_update_status(jira_ticket_id, assembla_ticket_state, assembla_ticket_status, index + 1)
  next unless result
  @jira_closed_tickets << {
    jira_ticket_id: jira_ticket_id,
    assembla_ticket_id: assembla_ticket_id,
    assembla_ticket_state: assembla_ticket_state,
    assembla_ticket_status: assembla_ticket_status
  }
end

puts "Total all: #{@jira_closed_tickets.length}"
closed_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-closed.csv"
write_csv_file(closed_tickets_jira_csv, @jira_closed_tickets)
