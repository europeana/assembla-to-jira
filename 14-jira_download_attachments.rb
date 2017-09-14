# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla attachments
tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"
attachments_assembla_csv = "#{dirname_assembla}/ticket-attachments.csv"
@tickets_assembla = csv_to_array(tickets_assembla_csv)
@attachments_assembla = csv_to_array(attachments_assembla_csv)

total_attachments = @attachments_assembla.length
puts "Total attachments: #{total_attachments}"

@jira_attachments = []

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  attachments_initial = @attachments_assembla.length
  @attachments_assembla.select! do |attachment|
    # IMPORTANT: filter on create date of ticket to which the attachment belongs
    # and NOT the attachment
    ticket_id = attachment['ticket_id']
    ticket = @tickets_assembla.detect { |t| t['id'] == ticket_id }
    goodbye("cannot find ticket id='#{ticket_id}'") unless ticket
    item_newer_than?(ticket, tickets_created_on)
  end
  puts "Attachments: #{attachments_initial} => #{@attachments_assembla.length} ∆#{attachments_initial - @attachments_assembla.length}"
else
  puts "Attachments: #{@attachments_assembla.length}"
end

# IMPORTANT: Make sure that the attachments are ordered chronologically from first (oldest) to last (newest)
@attachments_assembla.sort! { |x, y| x['created_at'] <=> y['created_at'] }

@attachments_total = @attachments_assembla.length

attachments_dirname = "#{OUTPUT_DIR_JIRA}/attachments"
FileUtils.mkdir_p(attachments_dirname) unless File.directory?(attachments_dirname)

@authorization = "Basic #{Base64.encode64(JIRA_API_ADMIN_USER + ':' + ENV['JIRA_API_ADMIN_PASSWORD'])}"

@attachments_assembla.each_with_index do |attachment, index|
  url = attachment['url']
  id = attachment['id']
  created_at = attachment['created_at']
  assembla_ticket_id = attachment['ticket_id']
  content_type = attachment['content_type']
  counter = index + 1
  filename = attachment['filename']
  filepath = "#{attachments_dirname}/#{filename}"
  nr = 0
  while File.exist?(filepath)
    nr += 1
    goodbye("Failed for filepath='#{filepath}', nr=#{nr}") if nr > 999
    extname = File.extname(filepath)
    basename = File.basename(filepath, extname)
    dirname = File.dirname(filepath)
    basename.sub!(/\.\d{3}$/, '')
    filename = "#{basename}.#{nr.to_s.rjust(3, '0')}#{extname}"
    filepath = "#{dirname}/#{filename}"
  end
  # BUG: "http://api.assembla.com/v1/spaces/europeana-npc/documents/:id/download" should be:
  #      "http://api.assembla.com/spaces/europeana-npc/documents/:id/download/:id
  url.sub!(%r{v1/}, '')
  m = %r{documents/(.*)/download}.match(url)
  url += "/#{m[1]}"

  percentage = ((counter * 100) / @attachments_total).round.to_s.rjust(3)
  puts "#{percentage}% [#{counter}|#{@attachments_total}] #{created_at} #{assembla_ticket_id} '#{filename}' (#{content_type})"
  begin
    content = RestClient::Request.execute(method: :get, url: url)
    IO.binwrite(filepath, content)
    @jira_attachments << {
      created_at: created_at,
      assembla_attachment_id: id,
      assembla_ticket_id: assembla_ticket_id,
      filename: filename,
      content_type: content_type
    }
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  end
end

puts "Total all: #{@attachments_total}"
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
write_csv_file(attachments_jira_csv, @jira_attachments)
