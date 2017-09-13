# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla tickets
tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  tickets_initial = @tickets_assembla.length
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
  puts "Tickets: #{tickets_initial} => #{@tickets_assembla.length} ∆#{tickets_initial - @tickets_assembla.length}"
else
  puts "Tickets: #{@tickets_assembla.length}"
end

# Assembla comments
comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
@comments_assembla = csv_to_array(comments_assembla_csv)

# Ignore empty comments
@comments_assembla.select! { |comment| ! (comment['comment'].nil? || comment['comment'].strip.empty?) }

if tickets_created_on
  comments_initial = @comments_assembla.length
  @comments_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
  puts "Comments: #{comments_initial} => #{@comments_assembla.length} ∆#{comments_initial - @comments_assembla.length}"
else
  puts "Comments: #{@comments_assembla.length}"
end

images_dirname = "#{dirname_assembla}/downloads/images"
FileUtils.mkdir_p(images_dirname) unless File.directory?(images_dirname)

# @authorization = "Basic #{Base64.encode64(JIRA_API_ADMIN_USER + ':' + ENV['JIRA_API_ADMIN_PASSWORD'])}"
#
# @attachments_assembla.each_with_index do |attachment, index|
#   url = attachment['url']
#   id = attachment['id']
#   created_at = attachment['created_at']
#   assembla_ticket_id = attachment['ticket_id']
#   jira_ticket_id = @assembla_id_to_jira[assembla_ticket_id]
#   content_type = attachment['content_type']
#   counter = index + 1
#   filename = attachment['filename']
#   filepath = "#{attachments_dirname}/#{filename}"
#   nr = 0
#   while File.exists?(filepath)
#     nr += 1
#     goodbye("Failed for filepath='#{filepath}', nr=#{nr}") if nr > 999
#     extname = File.extname(filepath)
#     basename = File.basename(filepath, extname)
#     dirname = File.dirname(filepath)
#     basename.sub!(/\.\d{3}$/, '')
#     filename = "#{basename}.#{nr.to_s.rjust(3, '0')}#{extname}"
#     filepath = "#{dirname}/#{filename}"
#   end
#   # # "http://api.assembla.com/v1/spaces/europeana-npc/documents/:id/download" should be:
#   # # "http://api.assembla.com/spaces/europeana-npc/documents/:id/download/:id
#   url.sub!(%r{v1/}, '')
#   m = %r{documents/(.*)/download}.match(url)
#   url += "/#{m[1]}"
#   # url.sub!(/^http:\/\//,"http://#{ENV['ASSEMBLA_API_KEY']}:#{ENV['ASSEMBLA_API_SECRET']}@")
#   percentage = ((counter * 100) / @attachments_total).round.to_s.rjust(3)
#   puts "#{percentage}% [#{counter}|#{@attachments_total}] #{created_at} #{jira_ticket_id} #{assembla_ticket_id} '#{filename}' (#{content_type})"
#   # headers = { 'Authorization': @authorization, 'Content-Type': content_type}
#   begin
#     content = RestClient::Request.execute(method: :get, url: url)
#     IO.binwrite(filepath, content)
#     @jira_attachments << {
#        created_at: created_at,
#        assembla_attachment_id: id,
#        assembla_ticket_id: assembla_ticket_id,
#        jira_ticket_id: jira_ticket_id,
#        filename: filename,
#        content_type: content_type
#     }
#   rescue RestClient::ExceptionWithResponse => e
#     rest_client_exception(e, 'GET', url)
#   end
# end
#
# puts "Total all: #{@attachments_total}"
# attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
# write_csv_file(attachments_jira_csv, @jira_attachments)