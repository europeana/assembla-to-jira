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
@closed_tickets = @tickets_assembla.select { |ticket| ticket['state'].to_i.zero? }
@open_tickets = @tickets_assembla.reject { |ticket| ticket['state'].to_i.zero? }
@done_tickets = @closed_tickets.select { |ticket| ticket['status'].casecmp('done').zero? }
@invalid_tickets = @closed_tickets.select { |ticket| ticket['status'].casecmp('invalid').zero? }

total_tickets = @tickets_assembla.length
total_open_tickets = @open_tickets.length
total_closed_tickets = @closed_tickets.length
total_done_tickets = @done_tickets.length
total_invalid_tickets = @invalid_tickets.length

puts "Total tickets: #{total_tickets}, open=#{total_open_tickets}, closed=#{total_closed_tickets}, done=#{total_done_tickets}, invalid=#{total_invalid_tickets}"

# Some sanity checks just in case.
goodbye('Sanity checks => NOK, total tickets != open + closed') unless total_tickets == total_open_tickets + total_closed_tickets
goodbye('Sanity checks => NOK, total closed tickets != done + invalid') unless total_closed_tickets == total_done_tickets + total_invalid_tickets
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

# # POST /rest/api/2/issue/{issueIdOrKey}/comment
# def jira_create_comment(issue_id, user_id, comment, counter)
#   result = nil
#   url = "#{URL_JIRA_ISSUES}/#{issue_id}/comment"
#   user_login = @user_id_to_login[user_id]
#   author_link = user_login ? "[~#{user_login}]" : 'unknown (#{user_id})'
#   body = "Author #{author_link} | Created on #{date_time(comment['created_on'])}\n\n#{comment['comment']}"
#   payload = {
#     body: body
#   }.to_json
#   begin
#     response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
#     # TODO: Investigate why the following does not work, e.g. reporter can create own comments.
#     # response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers_user_login(user_login))
#     result = JSON.parse(response.body)
#     percentage = ((counter * 100) / @comments_total).round.to_s.rjust(3)
#     puts "#{percentage}% [#{counter}|#{@comments_total} POST #{url} => OK"
#   rescue RestClient::ExceptionWithResponse => e
#     # TODO: use following helper method for all RestClient calls in other files.
#     rest_client_exception(e, 'POST', url)
#   rescue => e
#     puts "#{percentage}% [#{counter}|#{@comments_total} POST #{url} => NOK (#{e.message})"
#   end
#   result
# end
#
# # IMPORTANT: Make sure that the comments are ordered chronologically from first (oldest) to last (newest)
# @comments_assembla.sort! { |x, y| x['created_on'] <=> y['created_on'] }
#
# @jira_comments = []
#
# @comments_assembla.each_with_index do |comment, index|
#   id = comment['id']
#   ticket_id = comment['ticket_id']
#   user_id = comment['user_id']
#   issue_id = @assembla_id_to_jira[ticket_id]
#   user_login = @user_id_to_login[user_id],
#   comment['comment'] = reformat_markdown(comment['comment'])
#   result = jira_create_comment(issue_id, user_id, comment, index + 1)
#   next unless result
#   comment_id = result['id']
#   @jira_comments << {
#     jira_comment_id: comment_id,
#     jira_ticket_id: issue_id,
#     assembla_comment_id: id,
#     assembla_ticket_id: ticket_id,
#     user_login: user_login,
#     body: comment['comment']
#   }
# end
#
# puts "Total all: #{@comments_total}"
# comments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments.csv"
# write_csv_file(comments_jira_csv, @jira_comments)
